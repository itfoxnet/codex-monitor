import CodexMonitorCore
import Foundation
import Observation

@MainActor
@Observable
final class AppPreferences {
  struct AuditEntry: Codable, Sendable {
    let occurredAt: Date
    let taskReference: String
    let kind: String
    let action: String
    let outcome: String
  }

  private struct CachedEnvelope: Codable {
    let version: Int
    let savedAt: Date
    let tasks: [TaskRecord]
  }

  private enum Key {
    static let codexPath = "codexPath"
    static let managedThreadIDs = "managedThreadIDs"
    static let notificationsEnabled = "notificationsEnabled"
    static let privacyMode = "privacyMode"
    static let cachedTasks = "cachedTasks"
    static let approvalAudit = "approvalAudit"
  }

  private let defaults: UserDefaults

  var codexPath: String {
    didSet { defaults.set(codexPath, forKey: Key.codexPath) }
  }

  var managedThreadIDs: Set<String> {
    didSet { defaults.set(Array(managedThreadIDs).sorted(), forKey: Key.managedThreadIDs) }
  }

  var notificationsEnabled: Bool {
    didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
  }

  var privacyMode: Bool {
    didSet { defaults.set(privacyMode, forKey: Key.privacyMode) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    codexPath = defaults.string(forKey: Key.codexPath) ?? ""
    managedThreadIDs = Set(defaults.stringArray(forKey: Key.managedThreadIDs) ?? [])
    notificationsEnabled = defaults.bool(forKey: Key.notificationsEnabled)
    privacyMode =
      defaults.object(forKey: Key.privacyMode) == nil
      ? true : defaults.bool(forKey: Key.privacyMode)
  }

  func cache(tasks: [TaskRecord]) {
    let sanitized =
      tasks
      .filter { $0.ownership == .hostedLive }
      .map(sanitizedTask)
    let envelope = CachedEnvelope(version: 1, savedAt: .now, tasks: sanitized)
    if let data = try? JSONEncoder().encode(envelope) {
      defaults.set(data, forKey: Key.cachedTasks)
    }
  }

  func loadCachedTasks() -> [TaskRecord] {
    guard let data = defaults.data(forKey: Key.cachedTasks) else { return [] }
    if let envelope = try? JSONDecoder().decode(CachedEnvelope.self, from: data) {
      guard envelope.version == 1,
        Date.now.timeIntervalSince(envelope.savedAt) <= 7 * 24 * 60 * 60
      else {
        defaults.removeObject(forKey: Key.cachedTasks)
        return []
      }
      return envelope.tasks.map(sanitizedTask)
    }

    // Migrate the pre-envelope Alpha cache once, applying current privacy rules.
    guard let legacyTasks = try? JSONDecoder().decode([TaskRecord].self, from: data) else {
      defaults.removeObject(forKey: Key.cachedTasks)
      return []
    }
    let migrated = legacyTasks.map(sanitizedTask)
    cache(tasks: migrated)
    return migrated
  }

  func clearLocalData() {
    codexPath = ""
    managedThreadIDs = []
    notificationsEnabled = false
    privacyMode = true
    defaults.removeObject(forKey: Key.cachedTasks)
    defaults.removeObject(forKey: Key.approvalAudit)
  }

  var auditCount: Int { loadAudit().count }

  func recordAudit(taskID: String, kind: AttentionKind, action: String, outcome: String) {
    var entries = loadAudit()
    entries.append(
      AuditEntry(
        occurredAt: .now,
        taskReference: StaffIdentity.shortID(for: taskID),
        kind: kind.rawValue,
        action: action,
        outcome: outcome
      ))
    entries = Array(entries.suffix(100))
    if let data = try? JSONEncoder().encode(entries) {
      defaults.set(data, forKey: Key.approvalAudit)
    }
  }

  private func loadAudit() -> [AuditEntry] {
    guard let data = defaults.data(forKey: Key.approvalAudit),
      let entries = try? JSONDecoder().decode([AuditEntry].self, from: data)
    else { return [] }
    return entries.filter { Date.now.timeIntervalSince($0.occurredAt) <= 30 * 24 * 60 * 60 }
  }

  private func sanitizedTask(_ task: TaskRecord) -> TaskRecord {
    var copy = task
    copy.projectID = "cached:\(ProjectIdentity.cacheIdentifier(task.cwd))"
    copy.cwd = task.projectName
    copy.preview = ""
    copy.lastSummary = nil
    copy.attentions = []
    copy.branch = nil
    copy.activeTurnID = nil
    if privacyMode { copy.title = "待重新同步的任务" }
    if copy.displayStatus == .running || copy.displayStatus == .needsApproval
      || copy.displayStatus == .needsInput
    {
      copy.displayStatus = .unknown
      copy.rawStatus = "cached"
    }
    return copy
  }
}
