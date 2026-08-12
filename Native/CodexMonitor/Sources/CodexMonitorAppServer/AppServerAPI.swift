import CodexMonitorCore
import CodexMonitorProtocol
import Foundation

public struct StartedTask: Equatable, Sendable {
  public let threadID: String
  public let turnID: String

  public init(threadID: String, turnID: String) {
    self.threadID = threadID
    self.turnID = turnID
  }
}

public struct AppServerAPI: Sendable {
  public let client: CodexAppServerClient

  public init(client: CodexAppServerClient) {
    self.client = client
  }

  public func initialize(version: String) async throws -> JSONValue {
    let params: JSONValue = [
      "clientInfo": [
        "name": "codex_monitor",
        "title": "Codex Monitor",
        "version": .string(version),
      ],
      "capabilities": [
        "experimentalApi": true,
        "optOutNotificationMethods": [
          "item/agentMessage/delta",
          "item/reasoning/summaryTextDelta",
          "item/reasoning/textDelta",
          "item/commandExecution/outputDelta",
          "thread/tokenUsage/updated",
        ],
      ],
    ]
    let response = try await client.send(.initialize, params: params)
    try await client.notify(.initialized)
    return response
  }

  public func listThreads(limit: Int = .max) async throws -> [JSONValue] {
    guard limit > 0 else { return [] }
    var threads: [JSONValue] = []
    var cursor: String?
    var seenCursors = Set<String>()

    while threads.count < limit {
      let response = try await listThreadPage(
        limit: min(100, limit - threads.count),
        cursor: cursor,
        useStateDBOnly: true
      )
      let page = response.threads
      threads.append(contentsOf: page.prefix(limit - threads.count))

      guard let nextCursor = response.nextCursor,
        !nextCursor.isEmpty,
        seenCursors.insert(nextCursor).inserted,
        !page.isEmpty
      else { break }
      cursor = nextCursor
    }
    return threads
  }

  /// Returns only the most recently updated page. This is intended for low-cost periodic
  /// discovery; callers that need a complete reconciliation should use `listThreads(limit:)`.
  public func listRecentThreads(limit: Int = 100) async throws -> [JSONValue] {
    guard limit > 0 else { return [] }
    return try await listThreadPage(
      limit: min(100, limit),
      cursor: nil,
      useStateDBOnly: true
    ).threads
  }

  public func listModels() async throws -> [ModelOption] {
    let response = try await client.send(
      .modelList,
      params: [
        "limit": 50,
        "includeHidden": false,
      ])
    return (response["data"]?.arrayValue ?? []).compactMap { model in
      guard let id = model["id"]?.stringValue ?? model["model"]?.stringValue else { return nil }
      let efforts = (model["supportedReasoningEfforts"]?.arrayValue ?? []).compactMap {
        $0["reasoningEffort"]?.stringValue
      }
      return ModelOption(
        id: id,
        displayName: model["displayName"]?.stringValue ?? id,
        isDefault: model["isDefault"]?.boolValue ?? false,
        reasoningEfforts: efforts
      )
    }
  }

  public func startTask(_ draft: TaskDraft) async throws -> StartedTask {
    guard ProjectIdentity.isExistingDirectory(draft.cwd) else {
      throw CodexHostError.invalidProjectDirectory
    }
    let projectPath = ProjectIdentity.normalizedPath(draft.cwd)
    var threadParams: [String: JSONValue] = [
      "cwd": .string(projectPath),
      "approvalPolicy": "on-request",
      "approvalsReviewer": "user",
      "sandbox": "workspace-write",
      "serviceName": "codex_monitor",
    ]
    if let model = draft.model, !model.isEmpty { threadParams["model"] = .string(model) }

    let threadResponse = try await client.send(.threadStart, params: .object(threadParams))
    guard let threadID = threadResponse["thread"]?["id"]?.stringValue else {
      throw CodexHostError.invalidResponse("thread/start.thread.id")
    }
    let turnID = try await startTurn(
      threadID: threadID, prompt: draft.prompt, cwd: projectPath, model: draft.model)
    return StartedTask(threadID: threadID, turnID: turnID)
  }

  public func resume(threadID: String) async throws -> JSONValue {
    try await client.send(.threadResume, params: ["threadId": .string(threadID)])
  }

  public func resumeAndStartTurn(threadID: String, prompt: String, cwd: String, model: String?)
    async throws -> String
  {
    _ = try await resume(threadID: threadID)
    return try await startTurn(threadID: threadID, prompt: prompt, cwd: cwd, model: model)
  }

  public func startTurn(threadID: String, prompt: String, cwd: String? = nil, model: String? = nil)
    async throws -> String
  {
    var params: [String: JSONValue] = [
      "threadId": .string(threadID),
      "input": [["type": "text", "text": .string(prompt)]],
      "approvalPolicy": "on-request",
      "approvalsReviewer": "user",
    ]
    if let cwd, !cwd.isEmpty { params["cwd"] = .string(ProjectIdentity.normalizedPath(cwd)) }
    if let model, !model.isEmpty { params["model"] = .string(model) }
    let response = try await client.send(.turnStart, params: .object(params))
    guard let turnID = response["turn"]?["id"]?.stringValue else {
      throw CodexHostError.invalidResponse("turn/start.turn.id")
    }
    return turnID
  }

  public func interrupt(threadID: String, turnID: String) async throws {
    _ = try await client.send(
      .turnInterrupt,
      params: [
        "threadId": .string(threadID),
        "turnId": .string(turnID),
      ])
  }

  public func respond(
    to request: AttentionRequest,
    decision: ApprovalDecision,
    answers: [String: [String]] = [:]
  ) async throws {
    let generation = await client.currentGeneration
    guard generation == request.generation else { throw CodexHostError.staleApproval }

    let result: JSONValue
    switch request.kind {
    case .commandApproval, .fileApproval:
      result = ["decision": .string(decision.rawValue)]
    case .permissions:
      let permissions: JSONValue =
        decision == .accept ? (request.requestedPermissions ?? .object([:])) : .object([:])
      result = ["permissions": permissions, "scope": "turn"]
    case .userInput:
      let mapped = answers.mapValues { values in
        JSONValue.object(["answers": .array(values.map(JSONValue.string))])
      }
      result = ["answers": .object(mapped)]
    }
    try await client.respond(to: request.rpcID, result: result, generation: request.generation)
  }

  public func rejectUnknownRequest(id: RPCID, generation: UInt64) async {
    try? await client.respondError(to: id, generation: generation)
  }

  private func listThreadPage(limit: Int, cursor: String?, useStateDBOnly: Bool) async throws -> (
    threads: [JSONValue], nextCursor: String?
  ) {
    var params: [String: JSONValue] = [
      "limit": .number(Double(limit)),
      "sortKey": "updated_at",
      "sortDirection": "desc",
      "sourceKinds": ["appServer", "cli", "vscode", "exec"],
      "archived": false,
    ]
    if useStateDBOnly { params["useStateDbOnly"] = true }
    if let cursor { params["cursor"] = .string(cursor) }

    let response = try await client.send(.threadList, params: .object(params))
    guard let threads = response["data"]?.arrayValue else {
      throw CodexHostError.invalidResponse("thread/list.data")
    }
    return (threads, response["nextCursor"]?.stringValue)
  }
}
