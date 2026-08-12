import CodexMonitorProtocol
import Foundation

public enum TaskFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case attention
  case running
  case completed
  case waiting
  case history

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .all: "全部会话"
    case .attention: "举手"
    case .running: "办理中"
    case .completed: "已完成"
    case .waiting: "等待中"
    case .history: "历史档案"
    }
  }
}

public enum ConnectionPhase: String, Codable, Sendable {
  case disconnected
  case detecting
  case starting
  case initializing
  case syncing
  case online
  case reconnecting
  case unavailable
}

public struct ConnectionStatus: Codable, Equatable, Sendable {
  public var phase: ConnectionPhase
  public var detail: String
  public var version: String?
  public var executablePath: String?
  public var generation: UInt64
  public var updatedAt: Date

  public init(
    phase: ConnectionPhase = .disconnected,
    detail: String = "尚未连接",
    version: String? = nil,
    executablePath: String? = nil,
    generation: UInt64 = 0,
    updatedAt: Date = .now
  ) {
    self.phase = phase
    self.detail = detail
    self.version = version
    self.executablePath = executablePath
    self.generation = generation
    self.updatedAt = updatedAt
  }

  public var isOnline: Bool { phase == .online }
}

public enum TaskOwnership: String, Codable, Equatable, Sendable {
  case hostedLive
  case historyOnly
}

public enum TaskDisplayStatus: String, Codable, CaseIterable, Equatable, Sendable {
  case running
  case waiting
  case needsApproval
  case needsInput
  case completedUnseen
  case completedSeen
  case failed
  case interrupted
  case unknown
  case historyOnly

  public var title: String {
    switch self {
    case .running: "办理中"
    case .waiting: "等候安排"
    case .needsApproval: "举手申请"
    case .needsInput: "请示经理"
    case .completedUnseen: "完成汇报"
    case .completedSeen: "已汇报"
    case .failed: "异常汇报"
    case .interrupted: "办理中止"
    case .unknown: "状态待核实"
    case .historyOnly: "历史档案"
    }
  }

  public var attentionPriority: Int {
    switch self {
    case .needsApproval: 0
    case .needsInput: 1
    case .failed: 2
    case .completedUnseen: 3
    case .running: 4
    case .waiting: 5
    case .interrupted: 6
    case .unknown: 7
    case .completedSeen: 8
    case .historyOnly: 9
    }
  }

  public var needsManager: Bool {
    switch self {
    case .needsApproval, .needsInput, .failed, .completedUnseen: true
    default: false
    }
  }
}

public enum AttentionKind: String, Codable, Equatable, Sendable {
  case commandApproval
  case fileApproval
  case permissions
  case userInput

  public var title: String {
    switch self {
    case .commandApproval: "请求命令授权"
    case .fileApproval: "请求修改文件"
    case .permissions: "请求访问权限"
    case .userInput: "需要经理补充信息"
    }
  }
}

public enum AttentionState: String, Codable, Equatable, Sendable {
  case open
  case responding
  case resolved
  case expired
}

public enum ApprovalDecision: String, Codable, CaseIterable, Equatable, Sendable {
  case accept
  case decline
  case cancel

  public var title: String {
    switch self {
    case .accept: "一次允许"
    case .decline: "拒绝"
    case .cancel: "取消任务"
    }
  }
}

public struct UserInputOption: Codable, Equatable, Hashable, Sendable, Identifiable {
  public let label: String
  public let description: String

  public init(label: String, description: String) {
    self.label = label
    self.description = description
  }

  public var id: String { label }
}

public struct UserInputQuestion: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let header: String
  public let question: String
  public let options: [UserInputOption]
  public let allowsOther: Bool
  public let isSecret: Bool

  public init(
    id: String,
    header: String,
    question: String,
    options: [UserInputOption] = [],
    allowsOther: Bool = false,
    isSecret: Bool = false
  ) {
    self.id = id
    self.header = header
    self.question = question
    self.options = options
    self.allowsOther = allowsOther
    self.isSecret = isSecret
  }
}

public struct AttentionRequest: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let rpcID: RPCID
  public let generation: UInt64
  public let threadID: String
  public let turnID: String
  public let itemID: String
  public let kind: AttentionKind
  public let title: String
  public let reason: String?
  public let command: String?
  public let workingDirectory: String?
  public let requestedPermissions: JSONValue?
  public let questions: [UserInputQuestion]
  public var state: AttentionState
  public let createdAt: Date

  public init(
    rpcID: RPCID,
    generation: UInt64,
    threadID: String,
    turnID: String,
    itemID: String,
    kind: AttentionKind,
    title: String,
    reason: String? = nil,
    command: String? = nil,
    workingDirectory: String? = nil,
    requestedPermissions: JSONValue? = nil,
    questions: [UserInputQuestion] = [],
    state: AttentionState = .open,
    createdAt: Date = .now
  ) {
    self.id = "\(generation):\(rpcID.description)"
    self.rpcID = rpcID
    self.generation = generation
    self.threadID = threadID
    self.turnID = turnID
    self.itemID = itemID
    self.kind = kind
    self.title = title
    self.reason = reason
    self.command = command
    self.workingDirectory = workingDirectory
    self.requestedPermissions = requestedPermissions
    self.questions = questions
    self.state = state
    self.createdAt = createdAt
  }
}

public struct TaskRecord: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public var sessionID: String
  public var projectID: String
  public var cwd: String
  public var title: String
  public var preview: String
  public var source: String
  public var ownership: TaskOwnership
  public var displayStatus: TaskDisplayStatus
  public var rawStatus: String
  public var branch: String?
  public var createdAt: Date
  public var updatedAt: Date
  public var activeTurnID: String?
  public var lastSummary: String?
  public var attentions: [AttentionRequest]

  public init(
    id: String,
    sessionID: String,
    projectID: String,
    cwd: String,
    title: String,
    preview: String = "",
    source: String = "unknown",
    ownership: TaskOwnership,
    displayStatus: TaskDisplayStatus,
    rawStatus: String,
    branch: String? = nil,
    createdAt: Date = .now,
    updatedAt: Date = .now,
    activeTurnID: String? = nil,
    lastSummary: String? = nil,
    attentions: [AttentionRequest] = []
  ) {
    self.id = id
    self.sessionID = sessionID
    self.projectID = projectID
    self.cwd = cwd
    self.title = title
    self.preview = preview
    self.source = source
    self.ownership = ownership
    self.displayStatus = displayStatus
    self.rawStatus = rawStatus
    self.branch = branch
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.activeTurnID = activeTurnID
    self.lastSummary = lastSummary
    self.attentions = attentions
  }

  public var projectName: String {
    URL(fileURLWithPath: cwd).lastPathComponent.isEmpty
      ? "未命名项目" : URL(fileURLWithPath: cwd).lastPathComponent
  }

  public var openAttentions: [AttentionRequest] {
    attentions.filter { $0.state == .open || $0.state == .responding }
  }

  public var isExternallyObserved: Bool {
    ownership == .historyOnly && rawStatus.hasPrefix("external")
  }

  public var isExternalActive: Bool {
    ownership == .historyOnly && rawStatus == "externalActive"
  }
}

public struct TaskMetrics: Equatable, Sendable {
  public private(set) var total = 0
  public private(set) var running = 0
  public private(set) var approval = 0
  public private(set) var attention = 0
  public private(set) var completedUnread = 0
  public private(set) var unknown = 0
  public private(set) var history = 0

  public init<S: Sequence>(tasks: S) where S.Element == TaskRecord {
    for task in tasks { record(task) }
  }

  mutating func record(_ task: TaskRecord) {
    total += 1
    if task.displayStatus == .running { running += 1 }
    if task.displayStatus == .needsApproval || task.displayStatus == .needsInput {
      approval += 1
    }
    if task.displayStatus.needsManager { attention += 1 }
    if task.displayStatus == .completedUnseen { completedUnread += 1 }
    if task.displayStatus == .unknown { unknown += 1 }
    if task.displayStatus == .historyOnly { history += 1 }
  }
}

public struct TaskQueryScope: Equatable, Hashable, Sendable {
  public let projectID: String?
  public let filter: TaskFilter
  public let query: String
  public let hidesSensitiveContent: Bool

  public init(
    projectID: String?,
    filter: TaskFilter,
    query: String,
    hidesSensitiveContent: Bool = false
  ) {
    self.projectID = projectID
    self.filter = filter
    self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    self.hidesSensitiveContent = hidesSensitiveContent
  }

  public func matches(_ task: TaskRecord) -> Bool {
    if let projectID, task.projectID != projectID { return false }
    switch filter {
    case .all:
      break
    case .attention where !task.displayStatus.needsManager:
      return false
    case .running where task.displayStatus != .running:
      return false
    case .completed where ![.completedUnseen, .completedSeen].contains(task.displayStatus):
      return false
    case .waiting where ![.waiting, .interrupted, .unknown].contains(task.displayStatus):
      return false
    case .history where task.displayStatus != .historyOnly:
      return false
    default:
      break
    }

    guard !query.isEmpty else { return true }
    var searchableValues = [
      task.id,
      task.sessionID,
      task.displayStatus.title,
      StaffIdentity.name(for: task.id),
      StaffIdentity.shortID(for: task.id),
    ]
    if !hidesSensitiveContent {
      searchableValues.append(contentsOf: [task.title, task.projectName, task.branch ?? ""])
    }
    return searchableValues.contains { $0.localizedCaseInsensitiveContains(query) }
  }
}

public enum TaskSelectionPolicy {
  public static func retainedTaskID(
    afterSelecting projectID: String?,
    currentTaskID: String?,
    tasksByID: [String: TaskRecord]
  ) -> String? {
    guard let currentTaskID, let task = tasksByID[currentTaskID] else { return nil }
    guard let projectID else { return currentTaskID }
    return task.projectID == projectID ? currentTaskID : nil
  }
}

public enum StableTaskOrderPolicy {
  /// Keeps already-visible cards in their previous order while a manager is inspecting a task.
  /// Tasks that no longer match the active scope are omitted, and newly matching tasks are
  /// appended without moving existing click targets.
  public static func apply(previousOrder: [String], to tasks: [TaskRecord]) -> [TaskRecord] {
    guard !previousOrder.isEmpty, !tasks.isEmpty else { return tasks }
    let rank = Dictionary(uniqueKeysWithValues: previousOrder.enumerated().map { ($1, $0) })
    let existing = tasks.filter { rank[$0.id] != nil }.sorted {
      rank[$0.id, default: .max] < rank[$1.id, default: .max]
    }
    let newTasks = tasks.filter { rank[$0.id] == nil }
    return existing + newTasks
  }
}

public enum AdaptiveTaskGridPolicy {
  public static func columnCount(
    windowWidth: Double,
    sidebarWidth: Double = 230,
    inspectorWidth: Double = 0,
    horizontalPadding: Double = 40,
    minimumCardWidth: Double = 260,
    spacing: Double = 16
  ) -> Int {
    let contentWidth = max(
      minimumCardWidth,
      windowWidth - sidebarWidth - inspectorWidth - horizontalPadding
    )
    return max(1, Int((contentWidth + spacing) / (minimumCardWidth + spacing)))
  }
}

public enum PrivacyPreferencePolicy {
  /// Privacy rendering changes what the manager can see, so it is enabled only by an explicit
  /// stored choice. A missing value represents a fresh or pre-migration installation.
  public static func isEnabled(storedValue: Bool?) -> Bool {
    storedValue ?? false
  }
}

public enum ExternalObservationPolicy {
  /// App Server metadata can lag behind rollout activity for sessions owned by another Codex
  /// process. Every external session therefore remains eligible for the lightweight local-log
  /// observer; the observer itself avoids reading files that have not changed recently.
  public static func candidateThreadIDs<S: Sequence>(tasks: S) -> Set<String>
  where S.Element == TaskRecord {
    Set(tasks.lazy.filter { $0.ownership == .historyOnly }.map(\.id))
  }
}

public struct ProjectRecord: Equatable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let cwd: String
  public let tasks: [TaskRecord]
  public let metrics: TaskMetrics

  public init(id: String, name: String, cwd: String, tasks: [TaskRecord]) {
    self.id = id
    self.name = name
    self.cwd = cwd
    self.tasks = tasks
    metrics = TaskMetrics(tasks: tasks)
  }

  public var runningCount: Int { metrics.running }
  public var attentionCount: Int { metrics.attention }
  public var completedCount: Int {
    tasks.count { $0.displayStatus == .completedSeen || $0.displayStatus == .completedUnseen }
  }
}

public struct TaskDraft: Equatable, Sendable {
  public var cwd: String
  public var prompt: String
  public var model: String?

  public init(cwd: String = "", prompt: String = "", model: String? = nil) {
    self.cwd = cwd
    self.prompt = prompt
    self.model = model
  }

  public var isValid: Bool {
    !cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

public struct ModelOption: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let displayName: String
  public let isDefault: Bool
  public let reasoningEfforts: [String]

  public init(id: String, displayName: String, isDefault: Bool, reasoningEfforts: [String] = []) {
    self.id = id
    self.displayName = displayName
    self.isDefault = isDefault
    self.reasoningEfforts = reasoningEfforts
  }
}
