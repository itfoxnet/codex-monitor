import CodexMonitorCore
import SwiftUI

struct ProjectSidebar: View {
  @Environment(AppModel.self) private var model
  @FocusState private var projectSearchFocused: Bool
  @State private var searchHovered = false

  var body: some View {
    let visibleProjects = model.filteredProjects
    VStack(spacing: 0) {
      brandHeader
      projectUtilities
      Rectangle().fill(CMColor.hairline).frame(height: 0.5)
      ScrollView {
        LazyVStack(spacing: 3) {
          projectButton(
            id: nil,
            name: "全部项目",
            count: model.tasks.count,
            running: model.runningCount,
            attention: model.managerAttentionCount,
            history: model.historyCount
          )
          ForEach(visibleProjects) { project in
            projectButton(
              id: project.id,
              name: project.name,
              count: project.tasks.count,
              running: project.runningCount,
              attention: project.attentionCount,
              history: project.historyCount
            )
          }

          if visibleProjects.isEmpty {
            emptyProjects
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
      }
      .onHover { hovering in
        if hovering {
          model.beginProjectListInteraction()
        } else {
          model.endProjectListInteraction()
        }
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

  private var projectUtilities: some View {
    @Bindable var model = model
    @Bindable var preferences = model.preferences
    return VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(CMColor.muted)
          .accessibilityHidden(true)
        TextField(
          preferences.privacyMode ? "搜索匿名项目编号" : "搜索项目或路径",
          text: $model.projectSearchText
        )
        .textFieldStyle(.plain)
        .focused($projectSearchFocused)
        .onSubmit { model.updateProjectQuery() }
        .accessibilityLabel("搜索项目")
        if !model.projectSearchText.isEmpty {
          Button("清除") {
            model.projectSearchText = ""
            model.updateProjectQuery()
          }
          .controlSize(.mini)
          .buttonStyle(.bordered)
        }
      }
      .padding(.horizontal, 8)
      .frame(height: 30)
      .background(CMColor.porcelain.opacity(0.84), in: RoundedRectangle(cornerRadius: 6))
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(
            projectSearchFocused
              ? CMColor.focusRing : CMColor.ink.opacity(searchHovered ? 0.35 : 0.16),
            lineWidth: projectSearchFocused ? 1.5 : 0.75
          )
      )
      .onHover { searchHovered = $0 }
      .onChange(of: model.projectSearchText) { _, _ in model.updateProjectQuery() }

      VStack(alignment: .leading, spacing: 7) {
        LabeledContent("显示范围") {
          Picker("显示范围", selection: $model.projectFilter) {
            ForEach(ProjectListFilter.allCases) { filter in
              Text(filter.title).tag(filter)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.small)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .onChange(of: model.projectFilter) { _, _ in model.updateProjectQuery() }
          .accessibilityLabel("项目显示范围")
        }

        LabeledContent("排列方式") {
          Picker("排列方式", selection: $preferences.projectSort) {
            ForEach(ProjectSortOption.allCases) { option in
              Text(
                preferences.privacyMode && option == .name
                  ? "匿名编号" : option.title
              ).tag(option)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.small)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .onChange(of: preferences.projectSort) { _, _ in model.updateProjectQuery() }
          .accessibilityLabel("项目排列方式")
        }
      }
      .font(CMFont.caption)

      if model.hasActiveProjectQuery {
        Text("找到 \(model.filteredProjects.count) 个项目")
          .foregroundStyle(CMColor.ink)
          .font(CMFont.mono(9))
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private var emptyProjects: some View {
    VStack(spacing: 8) {
      Text("没有符合条件的项目")
        .font(CMFont.body(11, weight: .medium))
        .foregroundStyle(CMColor.muted)
      Button("清除筛选") { model.clearProjectQuery() }
        .controlSize(.small)
        .buttonStyle(.bordered)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
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
    let privacyMode = model.preferences.privacyMode
    let displayName = privacyMode ? privateProjectName(id: id) : name
    let sourceHint = id == nil ? "工作台总览" : projectSourceHint(for: id)
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
      model.selectProject(id: id)
    } label: {
      HStack(spacing: 10) {
        Circle()
          .fill(attention > 0 ? CMColor.raiseRed : running > 0 ? CMColor.workOrange : CMColor.muted)
          .frame(width: 8, height: 8)
        VStack(alignment: .leading, spacing: 3) {
          Text(displayName)
            .font(CMFont.body(13, weight: .semibold))
            .lineLimit(1)
            .truncationMode(.middle)
            .help(privacyMode ? "隐私模式已隐藏项目名称" : name)
          Text(activitySummary)
            .font(CMFont.mono(9))
            .foregroundStyle(CMColor.muted)
          if let id, model.projectIsOutsideCurrentQuery(id) {
            Text("当前项目 · 不符合筛选")
              .font(CMFont.caption2)
              .foregroundStyle(CMColor.workOrange)
          }
        }
        Spacer(minLength: 4)
        Text("\(count)")
          .font(CMFont.mono(10))
          .foregroundStyle(CMColor.muted)
      }
      .foregroundStyle(CMColor.ink)
      .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
      .contentShape(Rectangle())
      .padding(.horizontal, 10)
    }
    .buttonStyle(CMRowButtonStyle(selected: selected))
    .cmKeyboardFocusable()
    .help(privacyMode ? sourceHint : "\(name)\n\(sourceHint)")
    .accessibilityLabel(
      "\(displayName)，\(sourceHint)，共 \(count) 个会话，\(running) 个办理中，\(attention) 个举手，\(history) 个历史档案"
    )
  }

  private func projectSourceHint(for id: String?) -> String {
    guard let id else { return "工作台总览" }
    let normalized = id.replacingOccurrences(of: "\\", with: "/")
    if normalized.contains("/Documents/Codex/") {
      return "Codex 工作目录"
    }
    if normalized.hasPrefix("cached:") {
      return "本地缓存记录"
    }
    return "会话工作目录"
  }

  private func privateProjectName(id: String?) -> String {
    guard let id else { return "全部项目" }
    return "保密项目 · \(StaffIdentity.privateReference(for: id))"
  }
}
