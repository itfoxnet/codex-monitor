import AppKit
import CodexMonitorCore
import SwiftUI

struct MenuBarPanel: View {
  @Environment(AppModel.self) private var model
  @Environment(AppCoordinator.self) private var coordinator

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("CODEX MONITOR").font(CMFont.mono(9, weight: .bold)).tracking(1.6)
          Text("经理巡视台").font(CMFont.display(18, weight: .bold))
        }
        Spacer()
        ConnectionBadge(status: model.connection)
      }
      .padding(16)
      .background(CMColor.ink)
      .foregroundStyle(CMColor.porcelain)

      HStack(spacing: 0) {
        menuMetric(value: model.runningCount, label: "办理中", color: CMColor.workOrange)
        menuMetric(value: model.managerAttentionCount, label: "举手", color: CMColor.raiseRed)
        menuMetric(value: model.completedUnreadCount, label: "刚完成", color: CMColor.reportGreen)
      }
      .background(CMColor.warmPaper)

      if model.attentionTasks.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle")
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(CMColor.reportGreen)
          Text("暂时没有职员举手")
            .font(CMFont.body(12, weight: .semibold))
          Text(model.connection.detail)
            .font(CMFont.body(10))
            .foregroundStyle(CMColor.muted)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(CMColor.porcelain)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          Text("需要你处理")
            .font(CMFont.body(11, weight: .bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
          ForEach(model.attentionTasks.prefix(5)) { task in
            Button {
              open(task)
            } label: {
              HStack(spacing: 10) {
                Image(systemName: task.displayStatus.symbol)
                  .foregroundStyle(task.displayStatus.color)
                  .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                  Text(
                    "\(StaffIdentity.name(for: task.id)) · \(model.preferences.displayProjectName(for: task))"
                  )
                  .font(CMFont.body(11, weight: .semibold))
                  .lineLimit(1)
                  .truncationMode(.middle)
                  Text(task.displayStatus.title)
                    .font(CMFont.mono(9))
                    .foregroundStyle(CMColor.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9))
              }
              .foregroundStyle(CMColor.ink)
              .padding(.horizontal, 14)
              .padding(.vertical, 9)
            }
            .buttonStyle(CMMenuRowButtonStyle())
            .accessibilityLabel(
              "\(StaffIdentity.name(for: task.id))，\(model.preferences.displayProjectName(for: task))，\(task.displayStatus.title)"
            )
            Divider().padding(.leading, 48)
          }
          if model.attentionTasks.count > 5 {
            Button {
              model.filter = .attention
              openMainWindow()
            } label: {
              HStack {
                Text("另有 \(model.attentionTasks.count - 5) 项需要处理")
                Spacer()
                Text("查看全部")
                  .fontWeight(.semibold)
                Image(systemName: "arrow.right")
                  .font(.system(size: 10, weight: .semibold))
              }
              .font(CMFont.body(11))
              .foregroundStyle(CMColor.ink)
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .contentShape(Rectangle())
            }
            .buttonStyle(CMMenuRowButtonStyle())
            .accessibilityLabel("另有 \(model.attentionTasks.count - 5) 项需要处理，查看全部")
          }
        }
        .background(CMColor.porcelain)
      }

      HStack {
        Button {
          openMainWindow()
        } label: {
          Label("打开经理工作台", systemImage: "macwindow")
        }
        .buttonStyle(.borderedProminent)
        .tint(CMColor.ink)
        .help("显示唯一的经理工作台窗口")
        Spacer()
        Button {
          NSApplication.shared.terminate(nil)
        } label: {
          Image(systemName: "power")
        }
        .buttonStyle(CMIconButtonStyle(destructive: true))
        .help("退出 Codex Monitor")
        .accessibilityLabel("退出 Codex Monitor")

        Button {
          coordinator.present(.settings)
        } label: {
          Image(systemName: "slider.horizontal.3")
        }
        .buttonStyle(CMIconButtonStyle(tint: CMColor.muted))
        .help("设置")
        .accessibilityLabel("打开设置")
      }
      .font(CMFont.body(11, weight: .semibold))
      .padding(14)
      .background(CMColor.warmPaper)
      .overlay(alignment: .top) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }
    }
    .frame(width: 360)
  }

  private func menuMetric(value: Int, label: String, color: Color) -> some View {
    VStack(spacing: 2) {
      HStack(spacing: 5) {
        Circle().fill(color).frame(width: 6, height: 6)
        Text("\(value)").font(CMFont.display(18, weight: .bold))
      }
      Text(label).font(CMFont.body(9)).foregroundStyle(CMColor.muted)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 11)
    .overlay(alignment: .trailing) { Rectangle().fill(CMColor.hairline).frame(width: 0.5) }
  }

  private func open(_ task: TaskRecord) {
    model.selectTask(task)
    openMainWindow()
  }

  private func openMainWindow() {
    coordinator.showMainWindow()
  }
}
