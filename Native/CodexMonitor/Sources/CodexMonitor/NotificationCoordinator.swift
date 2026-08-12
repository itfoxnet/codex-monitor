import CodexMonitorCore
import Foundation
import UserNotifications

actor NotificationCoordinator {
  private var pendingCompletions: [String: TaskRecord] = [:]
  private var pendingCompletionPrivacyModes: [String: Bool] = [:]
  private var completionFlushTask: Task<Void, Never>?

  func requestAuthorization() async -> Bool {
    do {
      return try await UNUserNotificationCenter.current().requestAuthorization(options: [
        .alert, .sound, .badge,
      ])
    } catch {
      return false
    }
  }

  func notify(
    task: TaskRecord,
    title: String,
    body: String,
    privacyMode: Bool = true
  ) async {
    await deliver(
      identifier:
        "\(task.id)-\(task.displayStatus.rawValue)-\(Int(task.updatedAt.timeIntervalSince1970))",
      title: privacyMode ? "Codex Monitor 有一项新动态" : title,
      body: privacyMode ? "打开工作台查看详情" : body,
      threadID: task.id
    )
  }

  func notifyCompletion(task: TaskRecord, privacyMode: Bool = true) {
    var notificationTask = task
    if privacyMode {
      notificationTask.cwd = "项目已隐藏"
      notificationTask.title = "任务预览已隐藏"
    }
    pendingCompletions[task.id] = notificationTask
    pendingCompletionPrivacyModes[task.id] = privacyMode
    guard completionFlushTask == nil else { return }
    completionFlushTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(10))
      await self?.flushCompletions()
    }
  }

  func clear() {
    completionFlushTask?.cancel()
    completionFlushTask = nil
    pendingCompletions.removeAll()
    pendingCompletionPrivacyModes.removeAll()
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
  }

  private func flushCompletions() async {
    let tasks = Array(pendingCompletions.values)
    let privacyModes = pendingCompletionPrivacyModes
    pendingCompletions.removeAll()
    pendingCompletionPrivacyModes.removeAll()
    completionFlushTask = nil
    guard !tasks.isEmpty else { return }

    if let task = tasks.first, tasks.count == 1 {
      let privacyMode = privacyModes[task.id] ?? true
      await deliver(
        identifier: "\(task.id)-completion-\(Int(task.updatedAt.timeIntervalSince1970))",
        title: privacyMode ? "Codex Monitor 有一项任务完成" : "\(StaffIdentity.name(for: task.id)) 完成汇报",
        body: privacyMode ? "打开工作台查看详情" : task.projectName,
        threadID: task.id
      )
      return
    }

    let isPrivate = tasks.contains { privacyModes[$0.id] ?? true }
    let projects = Array(Set(tasks.map(\.projectName))).sorted().prefix(3).joined(separator: "、")
    await deliver(
      identifier: "completion-batch-\(Int(Date.now.timeIntervalSince1970))",
      title: isPrivate ? "Codex Monitor 有 \(tasks.count) 项任务完成" : "\(tasks.count) 位职员完成汇报",
      body: isPrivate ? "打开工作台查看详情" : projects,
      threadID: tasks.first?.id
    )
  }

  private func deliver(identifier: String, title: String, body: String, threadID: String?) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    if let threadID { content.userInfo = ["threadID": threadID] }
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: nil
    )
    try? await UNUserNotificationCenter.current().add(request)
  }
}
