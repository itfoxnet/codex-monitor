import CodexMonitorProtocol
import Foundation

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
}

public struct ProjectRecord: Equatable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let cwd: String
  public let tasks: [TaskRecord]

  public init(id: String, name: String, cwd: String, tasks: [TaskRecord]) {
    self.id = id
    self.name = name
    self.cwd = cwd
    self.tasks = tasks
  }

  public var runningCount: Int { tasks.count { $0.displayStatus == .running } }
  public var attentionCount: Int { tasks.count { $0.displayStatus.needsManager } }
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
