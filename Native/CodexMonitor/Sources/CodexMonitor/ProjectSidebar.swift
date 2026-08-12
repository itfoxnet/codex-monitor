import CodexMonitorCore
import SwiftUI

struct ProjectSidebar: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(spacing: 0) {
      brandHeader
      ScrollView {
        LazyVStack(spacing: 8) {
          projectButton(
            id: nil,
            name: "全部项目",
            count: model.tasks.count,
            running: model.runningCount,
            attention: model.managerAttentionCount,
            history: model.historyCount
          )
          ForEach(model.board.projects) { project in
            projectButton(
              id: project.id,
              name: project.name,
              count: project.tasks.count,
              running: project.runningCount,
              attention: project.attentionCount,
              history: project.tasks.count { $0.displayStatus == .historyOnly }
            )
          }
        }
        .padding(12)
      }

      VStack(alignment: .leading, spacing: 6) {
        ConnectionBadge(status: model.connection)
        Text(model.connection.detail)
          .font(CMFont.body(10))
          .foregroundStyle(CMColor.muted)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(CMColor.ink.opacity(0.035))
      .overlay(alignment: .top) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }
    }
    .background(CMColor.warmPaper)
  }

  private var brandHeader: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 8).fill(CMColor.ink)
        VStack(spacing: -1) {
          Text("C").foregroundStyle(CMColor.porcelain)
          Text("M").foregroundStyle(CMColor.workOrange)
        }
        .font(CMFont.mono(14, weight: .semibold))
      }
      .frame(width: 42, height: 48)

      VStack(alignment: .leading, spacing: 2) {
        Text("LOCAL OPS")
          .font(CMFont.mono(9, weight: .semibold))
          .tracking(2)
          .foregroundStyle(CMColor.muted)
        Text("Codex Monitor")
          .font(CMFont.display(16))
          .foregroundStyle(CMColor.ink)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .overlay(alignment: .bottom) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }
  }

  private func projectButton(
    id: String?,
    name: String,
    count: Int,
    running: Int,
    attention: Int,
    history: Int
  ) -> some View {
    let selected = model.selectedProjectID == id
    let activitySummary: String =
      if attention > 0 {
        "\(running) 办理 · \(attention) 举手"
      } else if running > 0 && history > 0 {
        "\(running) 办理 · \(history) 档案"
      } else if running > 0 {
        "\(running) 办理"
      } else if history > 0 {
        "\(history) 个历史会话"
      } else {
        "暂无活动"
      }
    return Button {
      model.selectedProjectID = id
    } label: {
      HStack(spacing: 10) {
        Circle()
          .fill(attention > 0 ? CMColor.raiseRed : running > 0 ? CMColor.workOrange : CMColor.muted)
          .frame(width: 8, height: 8)
        VStack(alignment: .leading, spacing: 3) {
          Text(name)
            .font(CMFont.body(13, weight: .semibold))
            .lineLimit(1)
          Text(activitySummary)
            .font(CMFont.mono(9))
            .foregroundStyle(CMColor.muted)
        }
        Spacer(minLength: 4)
        Text("\(count)")
          .font(CMFont.mono(10))
          .foregroundStyle(CMColor.muted)
      }
      .foregroundStyle(CMColor.ink)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(selected ? CMColor.porcelain : .clear, in: RoundedRectangle(cornerRadius: 7))
      .overlay(alignment: .leading) {
        if selected {
          RoundedRectangle(cornerRadius: 2).fill(CMColor.ink).frame(width: 3).padding(.vertical, 3)
        }
      }
      .overlay(
        RoundedRectangle(cornerRadius: 7)
          .stroke(selected ? CMColor.hairline : .clear, lineWidth: 0.5)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      "\(name)，共 \(count) 个会话，\(running) 个办理中，\(attention) 个举手，\(history) 个历史档案"
    )
  }
}
