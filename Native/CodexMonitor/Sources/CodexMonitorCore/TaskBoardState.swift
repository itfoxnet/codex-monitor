import CodexMonitorProtocol
import Foundation

public struct TaskBoardState: Equatable, Sendable {
  public private(set) var tasksByID: [String: TaskRecord]

  public init(tasksByID: [String: TaskRecord] = [:]) {
    self.tasksByID = tasksByID
  }

  public var tasks: [TaskRecord] { Array(tasksByID.values) }

  public var projects: [ProjectRecord] {
    Dictionary(grouping: tasks, by: \.projectID)
      .map { id, tasks in
        let first = tasks[0]
        return ProjectRecord(
          id: id,
          name: first.projectName,
          cwd: first.cwd,
          tasks: tasks.sorted(by: Self.taskSort)
        )
      }
      .sorted { lhs, rhs in
        if lhs.attentionCount != rhs.attentionCount {
          return lhs.attentionCount > rhs.attentionCount
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
  }

  public mutating func mergeThreads(_ threads: [JSONValue], managedIDs: Set<String>) {
    var seen = Set<String>()
    for thread in threads {
      guard var incoming = Self.task(from: thread, managedIDs: managedIDs) else { continue }
      seen.insert(incoming.id)
      if let existing = tasksByID[incoming.id] {
        incoming.attentions = existing.attentions
        incoming.lastSummary = existing.lastSummary
        incoming.activeTurnID = existing.activeTurnID
        if incoming.ownership == .hostedLive,
          incoming.rawStatus == "notLoaded",
          [.completedSeen, .completedUnseen, .failed, .interrupted].contains(existing.displayStatus)
        {
          incoming.displayStatus = existing.displayStatus
        } else if incoming.ownership == .historyOnly,
          existing.isExternallyObserved
        {
          incoming.displayStatus = existing.displayStatus
          incoming.rawStatus = existing.rawStatus
          incoming.updatedAt = max(incoming.updatedAt, existing.updatedAt)
        }
      }
      tasksByID[incoming.id] = incoming
    }

    for (id, task) in tasksByID where !seen.contains(id) && task.ownership == .historyOnly {
      tasksByID.removeValue(forKey: id)
    }
  }

  /// Adds threads found by a lightweight background discovery pass without treating the
  /// partial response as a complete server snapshot. Existing cards are intentionally left
  /// untouched so live lifecycle state cannot be rolled back and older cards are not removed.
  @discardableResult
  public mutating func mergeDiscoveredThreads(
    _ threads: [JSONValue],
    managedIDs: Set<String>
  ) -> Set<String> {
    var inserted = Set<String>()
    for thread in threads {
      guard let incoming = Self.task(from: thread, managedIDs: managedIDs),
        tasksByID[incoming.id] == nil
      else { continue }
      tasksByID[incoming.id] = incoming
      inserted.insert(incoming.id)
    }
    return inserted
  }

  public mutating func upsertThread(_ thread: JSONValue, managedIDs: Set<String>) {
    guard var incoming = Self.task(from: thread, managedIDs: managedIDs) else { return }
    if let existing = tasksByID[incoming.id] {
      incoming.attentions = existing.attentions
      incoming.lastSummary = existing.lastSummary
      incoming.activeTurnID = existing.activeTurnID
    }
    tasksByID[incoming.id] = incoming
  }

  public mutating func markManaged(threadID: String) {
    guard var task = tasksByID[threadID] else { return }
    task.ownership = .hostedLive
    if task.displayStatus == .historyOnly { task.displayStatus = .waiting }
    task.updatedAt = .now
    tasksByID[threadID] = task
  }

  public mutating func applyExternalSessionSnapshots(
    _ snapshots: [String: ExternalSessionSnapshot],
    reportNewCompletionsFor newlyDiscoveredThreadIDs: Set<String> = [],
    now: Date = .now,
    activeFreshness: TimeInterval = 10 * 60,
    incidentFreshness: TimeInterval = 2 * 60 * 60
  ) {
    for (threadID, snapshot) in snapshots {
      updateTask(threadID) { task in
        guard task.ownership == .historyOnly else { return }
        let wasRunning = task.displayStatus == .running && task.rawStatus == "externalActive"
        let age = max(0, now.timeIntervalSince(snapshot.updatedAt))
        let isFreshActivity = age <= activeFreshness
        let isFreshIncident = age <= incidentFreshness
        switch snapshot.lifecycle {
        case .active:
          if isFreshActivity {
            task.displayStatus = .running
            task.rawStatus = "externalActive"
          } else {
            task.displayStatus = .historyOnly
            task.rawStatus = "notLoaded"
          }
        case .completed:
          task.rawStatus = "externalCompleted"
          if wasRunning || (newlyDiscoveredThreadIDs.contains(threadID) && isFreshActivity) {
            task.displayStatus = .completedUnseen
          } else if ![.completedUnseen, .completedSeen].contains(task.displayStatus) {
            task.displayStatus = .historyOnly
            task.rawStatus = "notLoaded"
          }
        case .failed:
          if wasRunning || isFreshIncident {
            task.displayStatus = .failed
            task.rawStatus = "externalFailed"
          } else {
            task.displayStatus = .historyOnly
            task.rawStatus = "notLoaded"
          }
        case .interrupted:
          if wasRunning || isFreshActivity {
            task.displayStatus = .interrupted
            task.rawStatus = "externalInterrupted"
          } else {
            task.displayStatus = .historyOnly
            task.rawStatus = "notLoaded"
          }
        case .unknown:
          task.displayStatus = .historyOnly
          task.rawStatus = "notLoaded"
        }
        task.updatedAt = max(task.updatedAt, snapshot.updatedAt)
      }
    }
  }

  public mutating func applyNotification(method: String, params: JSONValue) {
    switch method {
    case "thread/started":
      if let thread = params["thread"] {
        let managedIDs = Set(tasks.filter { $0.ownership == .hostedLive }.map(\.id))
        upsertThread(thread, managedIDs: managedIDs)
      }
    case "thread/status/changed":
      guard let threadID = params["threadId"]?.stringValue,
        let status = params["status"]
      else { return }
      updateStatus(threadID: threadID, status: status)
    case "turn/started":
      guard let threadID = params["threadId"]?.stringValue else { return }
      let turnID = params["turn"]?["id"]?.stringValue
      updateTask(threadID) { task in
        task.activeTurnID = turnID
        task.rawStatus = "active"
        task.displayStatus =
          task.openAttentions.isEmpty ? .running : statusForAttention(task.openAttentions)
        task.updatedAt = .now
      }
    case "turn/completed":
      guard let threadID = params["threadId"]?.stringValue else { return }
      let status = params["turn"]?["status"]?.stringValue ?? "unknown"
      let completedTurnID = params["turn"]?["id"]?.stringValue
      updateTask(threadID) { task in
        if let activeTurnID = task.activeTurnID,
          let completedTurnID,
          activeTurnID != completedTurnID
        {
          return
        }
        task.activeTurnID = nil
        task.rawStatus = status
        task.attentions = task.attentions.map { attention in
          var copy = attention
          if copy.state == .open || copy.state == .responding { copy.state = .resolved }
          return copy
        }
        switch status {
        case "completed": task.displayStatus = .completedUnseen
        case "failed": task.displayStatus = .failed
        case "interrupted": task.displayStatus = .interrupted
        default: task.displayStatus = .unknown
        }
        task.updatedAt = .now
      }
    case "item/completed":
      guard let threadID = params["threadId"]?.stringValue,
        let item = params["item"]
      else { return }
      if item["type"]?.stringValue == "agentMessage", let text = item["text"]?.stringValue {
        updateTask(threadID) { task in
          task.lastSummary = String(text.prefix(2_000))
          task.updatedAt = .now
        }
      }
    case "serverRequest/resolved":
      guard let threadID = params["threadId"]?.stringValue,
        let requestValue = params["requestId"],
        let requestID = try? RPCID(jsonValue: requestValue)
      else { return }
      updateTask(threadID) { task in
        task.attentions = task.attentions.map { attention in
          var copy = attention
          if copy.rpcID == requestID { copy.state = .resolved }
          return copy
        }
        if task.displayStatus == .needsApproval || task.displayStatus == .needsInput {
          task.displayStatus =
            task.openAttentions.isEmpty ? .running : statusForAttention(task.openAttentions)
        }
        task.updatedAt = .now
      }
    case "error":
      if let threadID = params["threadId"]?.stringValue {
        updateTask(threadID) { task in
          task.displayStatus = .failed
          task.rawStatus = "error"
          task.updatedAt = .now
        }
      }
    default:
      break
    }
  }

  @discardableResult
  public mutating func addServerRequest(
    id: RPCID,
    method: String,
    params: JSONValue,
    generation: UInt64
  ) -> AttentionRequest? {
    guard let kind = Self.attentionKind(for: method),
      let threadID = params["threadId"]?.stringValue,
      let turnID = params["turnId"]?.stringValue,
      let itemID = params["itemId"]?.stringValue,
      tasksByID[threadID]?.ownership == .hostedLive
    else { return nil }

    let questions = (params["questions"]?.arrayValue ?? []).compactMap(Self.question(from:))
    let request = AttentionRequest(
      rpcID: id,
      generation: generation,
      threadID: threadID,
      turnID: turnID,
      itemID: itemID,
      kind: kind,
      title: kind.title,
      reason: params["reason"]?.stringValue,
      command: params["command"]?.stringValue,
      workingDirectory: params["cwd"]?.stringValue,
      requestedPermissions: params["permissions"],
      questions: questions
    )

    updateTask(threadID) { task in
      task.attentions.removeAll { $0.id == request.id }
      task.attentions.append(request)
      task.displayStatus = kind == .userInput ? .needsInput : .needsApproval
      task.rawStatus = "waitingOnApproval"
      task.updatedAt = .now
    }
    return request
  }

  public mutating func markResponding(_ request: AttentionRequest) -> Bool {
    guard var task = tasksByID[request.threadID],
      let index = task.attentions.firstIndex(where: { $0.id == request.id && $0.state == .open })
    else {
      return false
    }
    task.attentions[index].state = .responding
    task.updatedAt = .now
    tasksByID[task.id] = task
    return true
  }

  public mutating func expireOpenRequests(olderThanGeneration generation: UInt64) {
    for id in tasksByID.keys {
      updateTask(id) { task in
        task.attentions = task.attentions.map { attention in
          var copy = attention
          if copy.generation < generation && (copy.state == .open || copy.state == .responding) {
            copy.state = .expired
          }
          return copy
        }
        if task.displayStatus == .needsApproval || task.displayStatus == .needsInput {
          task.displayStatus = .unknown
        }
      }
    }
  }

  public mutating func markCompletedSeen(threadID: String) {
    updateTask(threadID) { task in
      if task.displayStatus == .completedUnseen { task.displayStatus = .completedSeen }
    }
  }

  public mutating func restoreCompletedUnseen(threadID: String) {
    updateTask(threadID) { task in
      if task.displayStatus == .completedSeen { task.displayStatus = .completedUnseen }
    }
  }

  public mutating func restoreCachedTasks(_ tasks: [TaskRecord]) {
    for task in tasks { tasksByID[task.id] = task }
  }

  private mutating func updateStatus(threadID: String, status: JSONValue) {
    updateTask(threadID) { task in
      let raw = status["type"]?.stringValue ?? "unknown"
      task.rawStatus = raw
      guard task.ownership == .hostedLive else {
        task.displayStatus = .historyOnly
        return
      }
      switch raw {
      case "active":
        let flags = status["activeFlags"]?.arrayValue?.compactMap(\.stringValue) ?? []
        if flags.contains("waitingOnApproval") {
          task.displayStatus =
            task.openAttentions.contains { $0.kind == .userInput } ? .needsInput : .needsApproval
        } else {
          task.displayStatus = .running
        }
      case "idle":
        if ![.completedSeen, .completedUnseen, .failed, .interrupted].contains(task.displayStatus) {
          task.displayStatus = .waiting
        }
      case "systemError": task.displayStatus = .failed
      case "notLoaded": task.displayStatus = .waiting
      default: task.displayStatus = .unknown
      }
      task.updatedAt = .now
    }
  }

  private mutating func updateTask(_ id: String, _ body: (inout TaskRecord) -> Void) {
    guard var task = tasksByID[id] else { return }
    body(&task)
    tasksByID[id] = task
  }

  private static func task(from thread: JSONValue, managedIDs: Set<String>) -> TaskRecord? {
    guard let id = thread["id"]?.stringValue,
      let cwd = thread["cwd"]?.stringValue
    else { return nil }
    let ownership: TaskOwnership = managedIDs.contains(id) ? .hostedLive : .historyOnly
    let status = thread["status"] ?? .object(["type": .string("unknown")])
    let rawStatus = status["type"]?.stringValue ?? "unknown"
    let displayStatus: TaskDisplayStatus
    if ownership == .historyOnly {
      displayStatus = .historyOnly
    } else {
      switch rawStatus {
      case "active":
        let flags = status["activeFlags"]?.arrayValue?.compactMap(\.stringValue) ?? []
        displayStatus = flags.contains("waitingOnApproval") ? .needsApproval : .running
      case "idle", "notLoaded": displayStatus = .waiting
      case "systemError": displayStatus = .failed
      default: displayStatus = .unknown
      }
    }

    let preview = thread["preview"]?.stringValue ?? ""
    let name = thread["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    let firstLine = preview.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    let title = [name, firstLine].compactMap { $0 }.first { !$0.isEmpty } ?? "未命名任务"
    let created = Date(
      timeIntervalSince1970: thread["createdAt"]?.doubleValue ?? Date.now.timeIntervalSince1970)
    let updated = Date(
      timeIntervalSince1970: thread["updatedAt"]?.doubleValue ?? created.timeIntervalSince1970)
    let source = sourceName(thread["source"])
    let branch = thread["gitInfo"]?["branch"]?.stringValue
    let standardized = ProjectIdentity.normalizedPath(cwd)

    return TaskRecord(
      id: id,
      sessionID: thread["sessionId"]?.stringValue ?? id,
      projectID: standardized,
      cwd: standardized,
      title: String(title.prefix(160)),
      preview: String(preview.prefix(280)),
      source: source,
      ownership: ownership,
      displayStatus: displayStatus,
      rawStatus: rawStatus,
      branch: branch,
      createdAt: created,
      updatedAt: updated
    )
  }

  private static func sourceName(_ source: JSONValue?) -> String {
    if let value = source?.stringValue { return value }
    if source?["subAgent"] != nil { return "subAgent" }
    if let value = source?["custom"]?.stringValue { return value }
    return "unknown"
  }

  private static func attentionKind(for method: String) -> AttentionKind? {
    switch method {
    case "item/commandExecution/requestApproval": .commandApproval
    case "item/fileChange/requestApproval": .fileApproval
    case "item/permissions/requestApproval": .permissions
    case "item/tool/requestUserInput": .userInput
    default: nil
    }
  }

  private static func question(from value: JSONValue) -> UserInputQuestion? {
    guard let id = value["id"]?.stringValue,
      let header = value["header"]?.stringValue,
      let question = value["question"]?.stringValue
    else { return nil }
    let options = (value["options"]?.arrayValue ?? []).compactMap { option -> UserInputOption? in
      guard let label = option["label"]?.stringValue else { return nil }
      return UserInputOption(label: label, description: option["description"]?.stringValue ?? "")
    }
    return UserInputQuestion(
      id: id,
      header: header,
      question: question,
      options: options,
      allowsOther: value["isOther"]?.boolValue ?? false,
      isSecret: value["isSecret"]?.boolValue ?? false
    )
  }

  private static func taskSort(_ lhs: TaskRecord, _ rhs: TaskRecord) -> Bool {
    if lhs.displayStatus.attentionPriority != rhs.displayStatus.attentionPriority {
      return lhs.displayStatus.attentionPriority < rhs.displayStatus.attentionPriority
    }
    if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
    return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
  }
}

private func statusForAttention(_ requests: [AttentionRequest]) -> TaskDisplayStatus {
  requests.contains { $0.kind == .userInput } ? .needsInput : .needsApproval
}
