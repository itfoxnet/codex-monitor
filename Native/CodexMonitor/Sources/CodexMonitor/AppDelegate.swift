import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  weak var model: AppModel?
  private var terminationPending = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().delegate = self
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(workspaceDidWake),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
  }

  @objc private func workspaceDidWake() {
    Task { await model?.revalidateAfterWake() }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard !terminationPending, let model, !model.activeTasks.isEmpty else { return .terminateNow }

    let alert = NSAlert()
    alert.messageText = "仍有 \(model.activeTasks.count) 位职员正在办理"
    alert.informativeText = "完全退出会中断这些任务。关闭主窗口不会退出菜单栏应用。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "返回工作台")
    alert.addButton(withTitle: "中断并退出")
    guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }

    terminationPending = true
    Task { @MainActor in
      await model.interruptAllActiveTasks()
      sender.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let threadID = response.notification.request.content.userInfo["threadID"] as? String
    await MainActor.run { [weak self] in
      if let threadID {
        self?.model?.selectProject(id: nil)
        self?.model?.filter = .all
        self?.model?.selectTask(threadID: threadID)
      }
      NSApplication.shared.activate(ignoringOtherApps: true)
      NSApplication.shared.windows.first { $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
    }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }
}
