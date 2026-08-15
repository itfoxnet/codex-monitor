import AppKit
import CodexMonitorCore
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  weak var model: AppModel?
  private var coordinator: AppCoordinator?
  private var termination = TerminationTransaction()
  private var terminationAttemptID: UUID?
  private var terminationTask: Task<Void, Never>?
  private var terminationDeadlineTask: Task<Void, Never>?

  func configure(model: AppModel, coordinator: AppCoordinator) {
    self.model = model
    self.coordinator = coordinator
  }

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

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    coordinator?.showMainWindow()
    return true
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard termination.state == .idle else { return .terminateLater }
    guard let model else { return .terminateNow }

    guard !model.activeTasks.isEmpty else {
      guard termination.begin() else { return .terminateLater }
      beginTermination(sender: sender, model: model, interruptsActiveTasks: false)
      return .terminateLater
    }

    let alert = NSAlert()
    alert.messageText = "仍有 \(model.activeTasks.count) 位职员正在办理"
    alert.informativeText = "完全退出会中断这些任务。关闭主窗口不会退出菜单栏应用。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "返回工作台")
    alert.addButton(withTitle: "中断并退出")
    guard alert.runModal() == .alertSecondButtonReturn else {
      coordinator?.showMainWindow()
      return .terminateCancel
    }

    guard termination.begin() else { return .terminateLater }
    beginTermination(sender: sender, model: model, interruptsActiveTasks: true)
    return .terminateLater
  }

  private func beginTermination(
    sender: NSApplication,
    model: AppModel,
    interruptsActiveTasks: Bool
  ) {
    let attemptID = UUID()
    terminationAttemptID = attemptID

    terminationTask = Task { @MainActor [weak self, weak sender] in
      let interrupted: Bool
      if interruptsActiveTasks {
        interrupted = await model.interruptAllActiveTasks()
      } else {
        interrupted = true
      }
      guard interrupted, !Task.isCancelled else {
        self?.finishTermination(attemptID: attemptID, sender: sender, shouldTerminate: false)
        return
      }
      await model.shutdown()
      guard !Task.isCancelled else { return }
      self?.finishTermination(attemptID: attemptID, sender: sender, shouldTerminate: true)
    }

    terminationDeadlineTask = Task { @MainActor [weak self, weak sender] in
      do {
        try await Task.sleep(for: .seconds(10))
      } catch {
        return
      }
      self?.terminationTask?.cancel()
      self?.finishTermination(attemptID: attemptID, sender: sender, shouldTerminate: false)
      self?.model?.bannerMessage = "安全退出超时，应用仍在运行；请检查 Codex 连接后重试。"
    }
  }

  private func finishTermination(
    attemptID: UUID,
    sender: NSApplication?,
    shouldTerminate: Bool
  ) {
    guard terminationAttemptID == attemptID else { return }
    terminationAttemptID = nil
    terminationTask?.cancel()
    terminationDeadlineTask?.cancel()
    terminationTask = nil
    terminationDeadlineTask = nil
    termination.finish()
    sender?.reply(toApplicationShouldTerminate: shouldTerminate)
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let request = response.notification.request
    let route = NotificationRoute(
      userInfo: request.content.userInfo,
      identifier: request.identifier
    )
    await MainActor.run { [weak self] in
      self?.coordinator?.showMainWindow()
      switch route {
      case .task(let threadID):
        Task { @MainActor [weak self] in
          await self?.model?.revealTask(threadID: threadID)
        }
      case .completedCollection:
        self?.model?.revealCompletedCollection()
      case nil:
        break
      }
    }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }
}
