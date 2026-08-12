import AppKit
import SwiftUI

@main
struct CodexMonitorApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup("Codex Monitor", id: "main") {
      DashboardView()
        .environment(model)
        .task {
          appDelegate.model = model
          await model.start()
        }
    }
    .defaultSize(width: 1180, height: 760)
    .commands {
      CommandGroup(after: .newItem) {
        Button("交办任务") { model.isNewTaskPresented = true }
          .keyboardShortcut("n", modifiers: [.command, .shift])
          .disabled(!model.canManageTasks)
      }
      CommandGroup(replacing: .appTermination) {
        Button("退出 Codex Monitor") { NSApplication.shared.terminate(nil) }
          .keyboardShortcut("q", modifiers: [.command])
      }
      CommandMenu("任务") {
        Button("搜索任务") { model.searchFocusRequest += 1 }
          .keyboardShortcut("k", modifiers: [.command])
        Button("刷新状态") { Task { try? await model.refresh() } }
          .keyboardShortcut("r", modifiers: [.command])
          .disabled(!model.connection.isOnline)
        Button("只看举手") { model.filter = .attention }
          .keyboardShortcut("1", modifiers: [.command])
        Button("只看办理中") { model.filter = .running }
          .keyboardShortcut("2", modifiers: [.command])
        Button("只看已完成") { model.filter = .completed }
          .keyboardShortcut("3", modifiers: [.command])
        Button("只看等待中") { model.filter = .waiting }
          .keyboardShortcut("4", modifiers: [.command])
        Button("显示全部会话") { model.filter = .all }
          .keyboardShortcut("0", modifiers: [.command])
        Divider()
        Button("当前项目完成汇报全部已阅") { model.markCurrentProjectReportsSeen() }
          .keyboardShortcut("a", modifiers: [.command, .shift])
      }
    }

    MenuBarExtra {
      MenuBarPanel()
        .environment(model)
        .task {
          appDelegate.model = model
          await model.start()
        }
    } label: {
      Label(
        model.managerAttentionCount > 0 ? "\(model.managerAttentionCount) 个举手" : "Codex Monitor",
        systemImage: model.managerAttentionCount > 0 ? "hand.raised.fill" : "rectangle.3.group"
      )
    }
    .menuBarExtraStyle(.window)
  }
}
