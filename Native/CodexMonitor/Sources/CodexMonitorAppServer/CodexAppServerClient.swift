import CodexMonitorProtocol
import Foundation

public enum AppServerInbound: Equatable, Sendable {
  case notification(method: String, params: JSONValue, generation: UInt64)
  case serverRequest(id: RPCID, method: String, params: JSONValue, generation: UInt64)
  case protocolError(String, generation: UInt64)
  case terminated(status: Int32, generation: UInt64)
}

public actor CodexAppServerClient {
  public nonisolated let events: AsyncStream<AppServerInbound>

  private let eventContinuation: AsyncStream<AppServerInbound>.Continuation
  private var process: Process?
  private var inputHandle: FileHandle?
  private var outputHandle: FileHandle?
  private var errorHandle: FileHandle?
  private var outputReadTask: Task<Void, Never>?
  private var errorReadTask: Task<Void, Never>?
  private var framer = JSONLineFramer()
  private var pending: [RPCID: CheckedContinuation<JSONValue, Error>] = [:]
  private var nextRequestID = 1
  private var generation: UInt64 = 0
  private var diagnosticsBuffer = Data()
  private let diagnosticsLimit = 32 * 1_024

  public init() {
    let pair = AsyncStream<AppServerInbound>.makeStream(bufferingPolicy: .bufferingNewest(2_000))
    events = pair.stream
    eventContinuation = pair.continuation
  }

  deinit {
    eventContinuation.finish()
  }

  public var currentGeneration: UInt64 { generation }
  public var isRunning: Bool { process?.isRunning == true }

  @discardableResult
  public func start(executable: URL) throws -> UInt64 {
    guard process?.isRunning != true else { throw CodexHostError.alreadyRunning }

    generation &+= 1
    nextRequestID = 1
    framer = JSONLineFramer()
    diagnosticsBuffer.removeAll(keepingCapacity: true)

    let process = Process()
    let input = Pipe()
    let output = Pipe()
    let errors = Pipe()
    let activeGeneration = generation

    process.executableURL = executable
    process.arguments = ["app-server", "--listen", "stdio://"]
    process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
    process.environment = ProcessInfo.processInfo.environment
    process.standardInput = input
    process.standardOutput = output
    process.standardError = errors

    let outputStream = AsyncStream<Data>(bufferingPolicy: .unbounded) { continuation in
      output.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
          continuation.finish()
        } else {
          continuation.yield(data)
        }
      }
    }
    let errorStream = AsyncStream<Data>(bufferingPolicy: .unbounded) { continuation in
      errors.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
          continuation.finish()
        } else {
          continuation.yield(data)
        }
      }
    }
    process.terminationHandler = { [weak self] process in
      let status = process.terminationStatus
      Task { await self?.processTerminated(status: status, generation: activeGeneration) }
    }

    self.process = process
    inputHandle = input.fileHandleForWriting
    outputHandle = output.fileHandleForReading
    errorHandle = errors.fileHandleForReading

    do {
      try process.run()
      outputReadTask = Task { [weak self] in
        for await data in outputStream {
          guard !Task.isCancelled else { return }
          await self?.receive(data, generation: activeGeneration)
        }
      }
      errorReadTask = Task { [weak self] in
        for await data in errorStream {
          guard !Task.isCancelled else { return }
          await self?.receiveDiagnostics(data, generation: activeGeneration)
        }
      }
      return generation
    } catch {
      cleanupHandlers()
      self.process = nil
      inputHandle = nil
      outputHandle = nil
      errorHandle = nil
      throw error
    }
  }

  public func send(
    _ method: AllowedClientMethod,
    params: JSONValue = .object([:]),
    timeout: Duration = .seconds(12)
  ) async throws -> JSONValue {
    guard process?.isRunning == true else { throw CodexHostError.notRunning }
    let id = RPCID.integer(nextRequestID)
    nextRequestID += 1
    let data = try RPCMessageCodec.request(id: id, method: method.rawValue, params: params)

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        pending[id] = continuation
        Task { [weak self] in
          try? await Task.sleep(for: timeout)
          await self?.expireRequest(id, method: method.rawValue)
        }
        do {
          try write(data)
        } catch {
          pending.removeValue(forKey: id)
          continuation.resume(throwing: error)
        }
      }
    } onCancel: {
      Task { [weak self] in await self?.cancelRequest(id) }
    }
  }

  public func notify(_ method: AllowedClientNotification, params: JSONValue = .object([:])) throws {
    try write(RPCMessageCodec.notification(method: method.rawValue, params: params))
  }

  public func respond(to id: RPCID, result: JSONValue, generation responseGeneration: UInt64) throws
  {
    guard responseGeneration == generation else { throw CodexHostError.staleApproval }
    try write(RPCMessageCodec.response(id: id, result: result))
  }

  public func respondError(
    to id: RPCID,
    code: Int = -32_601,
    message: String = "Unsupported client request",
    generation responseGeneration: UInt64
  ) throws {
    guard responseGeneration == generation else { throw CodexHostError.staleApproval }
    try write(RPCMessageCodec.error(id: id, code: code, message: message))
  }

  public func stop() {
    guard let process else { return }
    cleanupHandlers()
    inputHandle?.closeFile()
    if process.isRunning { process.terminate() }
    failPending(with: CodexHostError.transportClosed)
    self.process = nil
    inputHandle = nil
    outputHandle = nil
    errorHandle = nil
  }

  public func sanitizedDiagnostics() -> String {
    let text = String(decoding: diagnosticsBuffer, as: UTF8.self)
    return
      text
      .split(whereSeparator: \.isNewline)
      .suffix(40)
      .map { line in
        var value = String(line)
        value = value.replacingOccurrences(
          of: #"/(Users|private|tmp)/[^\s\"']+"#,
          with: "<path>",
          options: .regularExpression
        )
        return String(value.prefix(500))
      }
      .joined(separator: "\n")
  }

  private func write(_ data: Data) throws {
    guard process?.isRunning == true, let inputHandle else { throw CodexHostError.transportClosed }
    try inputHandle.write(contentsOf: data)
  }

  private func receive(_ data: Data, generation messageGeneration: UInt64) {
    guard messageGeneration == generation else { return }
    for line in framer.append(data) {
      do {
        switch try RPCMessageCodec.decode(line) {
        case .response(let id, let result):
          pending.removeValue(forKey: id)?.resume(returning: result)
        case .failure(let id, let error):
          pending.removeValue(forKey: id)?.resume(throwing: error)
        case .request(let id, let method, let params):
          eventContinuation.yield(
            .serverRequest(id: id, method: method, params: params, generation: generation))
        case .notification(let method, let params):
          eventContinuation.yield(
            .notification(method: method, params: params, generation: generation))
        }
      } catch {
        eventContinuation.yield(.protocolError(error.localizedDescription, generation: generation))
      }
    }
  }

  private func receiveDiagnostics(_ data: Data, generation messageGeneration: UInt64) {
    guard messageGeneration == generation else { return }
    diagnosticsBuffer.append(data)
    if diagnosticsBuffer.count > diagnosticsLimit {
      diagnosticsBuffer.removeFirst(diagnosticsBuffer.count - diagnosticsLimit)
    }
  }

  private func processTerminated(status: Int32, generation terminatedGeneration: UInt64) {
    guard terminatedGeneration == generation else { return }
    cleanupHandlers()
    failPending(with: CodexHostError.transportClosed)
    process = nil
    inputHandle = nil
    outputHandle = nil
    errorHandle = nil
    eventContinuation.yield(.terminated(status: status, generation: terminatedGeneration))
  }

  private func cleanupHandlers() {
    outputReadTask?.cancel()
    errorReadTask?.cancel()
    outputReadTask = nil
    errorReadTask = nil
    outputHandle?.readabilityHandler = nil
    errorHandle?.readabilityHandler = nil
    process?.terminationHandler = nil
  }

  private func failPending(with error: Error) {
    let continuations = pending.values
    pending.removeAll()
    for continuation in continuations {
      continuation.resume(throwing: error)
    }
  }

  private func expireRequest(_ id: RPCID, method: String) {
    pending.removeValue(forKey: id)?.resume(throwing: CodexHostError.requestTimedOut(method))
  }

  private func cancelRequest(_ id: RPCID) {
    pending.removeValue(forKey: id)?.resume(throwing: CancellationError())
  }
}
