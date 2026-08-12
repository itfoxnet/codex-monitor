import CodexMonitorCore
import Foundation
import UserNotifications

actor NotificationCoordinator {
  private var pendingCompletions: [String: TaskRecord] = [:]
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

  func notify(task: TaskRecord, title: String, body: String) async {
    await deliver(
      identifier:
        "\(task.id)-\(task.displayStatus.rawValue)-\(Int(task.updatedAt.timeIntervalSince1970))",
      title: title,
      body: body,
      threadID: task.id
    )
  }

  func notifyCompletion(task: TaskRecord) {
    pendingCompletions[task.id] = task
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
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
  }

  private func flushCompletions() async {
    let tasks = Array(pendingCompletions.values)
    pendingCompletions.removeAll()
    completionFlushTask = nil
    guard !tasks.isEmpty else { return }

    if let task = tasks.first, tasks.count == 1 {
      await deliver(
        identifier: "\(task.id)-completion-\(Int(task.updatedAt.timeIntervalSince1970))",
        title: "\(StaffIdentity.name(for: task.id)) 完成汇报",
        body: task.projectName,
        threadID: task.id
      )
      return
    }

    let projects = Array(Set(tasks.map(\.projectName))).sorted().prefix(3).joined(separator: "、")
    await deliver(
      identifier: "completion-batch-\(Int(Date.now.timeIntervalSince1970))",
      title: "\(tasks.count) 位职员完成汇报",
      body: projects,
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
