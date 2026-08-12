import CodexProbeCore
import Darwin
import Foundation

enum AppServerTransport: String {
  case child = "stdio-child-process"
  case proxy = "daemon-proxy"
}

enum ProbeProcessError: Error, LocalizedError {
  case timedOut
  case serverClosed
  case writeFailed
  case unexpectedListResult
  case unexpectedReadResult

  var errorDescription: String? {
    switch self {
    case .timedOut:
      return "Timed out waiting for Codex App Server"
    case .serverClosed:
      return "Codex App Server closed the stdio connection"
    case .writeFailed:
      return "Could not write to Codex App Server"
    case .unexpectedListResult:
      return "thread/list returned an unexpected response shape"
    case .unexpectedReadResult:
      return "thread/read returned an unexpected response shape"
    }
  }
}

final class AppServerProcess {
  private let process = Process()
  private let inputPipe = Pipe()
  private let outputPipe = Pipe()
  private let errorPipe = Pipe()
  private let timeoutMilliseconds: Int32
  private var readBuffer = Data()
  private var nextRequestID = 1

  init(
    codexExecutable: String?,
    transport: AppServerTransport,
    socketPath: String?,
    timeoutSeconds: Int
  ) {
    timeoutMilliseconds = Int32(max(1, timeoutSeconds) * 1_000)

    let codexArguments: [String]
    switch transport {
    case .child:
      codexArguments = ["app-server", "--listen", "stdio://"]
    case .proxy:
      if let socketPath {
        codexArguments = ["app-server", "proxy", "--sock", socketPath]
      } else {
        codexArguments = ["app-server", "proxy"]
      }
    }

    if let codexExecutable {
      process.executableURL = URL(fileURLWithPath: codexExecutable)
      process.arguments = codexArguments
    } else {
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = ["codex"] + codexArguments
    }

    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe
  }

  deinit {
    stop()
  }

  func start() throws {
    try process.run()
  }

  func initialize() throws -> [String: Any] {
    let result = try request(
      method: "initialize",
      params: [
        "clientInfo": [
          "name": "codex_monitor_probe",
          "title": "Codex Monitor Read-Only Probe",
          "version": "0.1.0",
        ],
        "capabilities": [
          "optOutNotificationMethods": [
            "item/agentMessage/delta",
            "item/reasoning/textDelta",
            "item/reasoning/summaryTextDelta",
            "item/commandExecution/outputDelta",
          ]
        ],
      ]
    )
    try send(ReadOnlyRPCPolicy.makeNotification(method: "initialized"))
    return try result.requireResultObject()
  }

  func listThreads(cwd: String?, limit: Int) throws -> [[String: Any]] {
    var params: [String: Any] = [
      "limit": max(1, min(limit, 1_000)),
      "sortKey": "recency_at",
      "sortDirection": "desc",
      "useStateDbOnly": true,
      "sourceKinds": [
        "cli",
        "vscode",
        "exec",
        "appServer",
        "subAgent",
        "subAgentReview",
        "subAgentCompact",
        "subAgentThreadSpawn",
        "subAgentOther",
        "unknown",
      ],
    ]
    if let cwd {
      params["cwd"] = cwd
    }

    let response = try request(method: "thread/list", params: params)
    let result = try response.requireResultObject()
    guard let data = result["data"] as? [[String: Any]] else {
      throw ProbeProcessError.unexpectedListResult
    }
    return data
  }

  func readThread(id: String) throws -> [String: Any] {
    let response = try request(
      method: "thread/read",
      params: ["threadId": id, "includeTurns": false]
    )
    let result = try response.requireResultObject()
    guard let thread = result["thread"] as? [String: Any] else {
      throw ProbeProcessError.unexpectedReadResult
    }
    return thread
  }

  func loadedThreadIDs() throws -> Set<String> {
    let response = try request(method: "thread/loaded/list")
    let result = try response.requireResultObject()
    let ids = result["data"] as? [String] ?? []
    return Set(ids)
  }

  func stop() {
    inputPipe.fileHandleForWriting.closeFile()
    if process.isRunning {
      process.terminate()
      process.waitUntilExit()
    }
  }

  private func request(method: String, params: [String: Any] = [:]) throws -> JSONRPCMessage {
    let id = nextRequestID
    nextRequestID += 1
    try send(ReadOnlyRPCPolicy.makeRequest(method: method, id: id, params: params))

    while true {
      let line = try readLine()
      let message = try JSONRPCMessage(line: line)
      if message.id == id {
        return message
      }
    }
  }

  private func send(_ data: Data) throws {
    do {
      try inputPipe.fileHandleForWriting.write(contentsOf: data)
    } catch {
      throw ProbeProcessError.writeFailed
    }
  }

  private func readLine() throws -> Data {
    while true {
      if let newline = readBuffer.firstIndex(of: 0x0A) {
        let line = readBuffer[..<newline]
        readBuffer.removeSubrange(...newline)
        if !line.isEmpty {
          return Data(line)
        }
        continue
      }

      var descriptor = pollfd(
        fd: outputPipe.fileHandleForReading.fileDescriptor,
        events: Int16(POLLIN),
        revents: 0
      )
      let result = Darwin.poll(&descriptor, 1, timeoutMilliseconds)
      if result == 0 {
        throw ProbeProcessError.timedOut
      }
      if result < 0 {
        if errno == EINTR { continue }
        throw ProbeProcessError.serverClosed
      }

      var bytes = [UInt8](repeating: 0, count: 8_192)
      let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
      if count <= 0 {
        throw ProbeProcessError.serverClosed
      }
      readBuffer.append(bytes, count: count)
    }
  }
}
