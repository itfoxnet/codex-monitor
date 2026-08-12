import CodexMonitorCore
import SwiftUI

struct DashboardView: View {
  @Environment(AppModel.self) private var model
  @FocusState private var searchFocused: Bool

  var body: some View {
    @Bindable var model = model

    NavigationSplitView {
      ProjectSidebar()
        .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 270)
    } detail: {
      ZStack {
        OperationsGridBackground()
        VStack(spacing: 0) {
          workspaceHeader
          metricsStrip
          filterBar
          taskBoard
        }
      }
      .navigationTitle("工作台")
      .toolbar {
        ToolbarItemGroup {
          Button {
            model.isNewTaskPresented = true
          } label: {
            Label("交办任务", systemImage: "plus")
          }
          .disabled(!model.canManageTasks)

          Button {
            Task { try? await model.refresh() }
          } label: {
            Label("刷新", systemImage: "arrow.clockwise")
          }
          .disabled(!model.connection.isOnline)

          Button {
            model.isSettingsPresented = true
          } label: {
            Label("设置", systemImage: "slider.horizontal.3")
          }
        }
      }
    }
    .navigationSplitViewStyle(.balanced)
    .inspector(
      isPresented: Binding(
        get: { model.selectedTaskID != nil },
        set: { if !$0 { model.dismissTaskSelection() } }
      )
    ) {
      TaskDetailView()
        .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
    }
    .sheet(isPresented: $model.isNewTaskPresented) { NewTaskSheet() }
    .sheet(isPresented: $model.isSettingsPresented) { SettingsView() }
    .overlay(alignment: .top) {
      if let message = model.bannerMessage {
        NoticeBanner(message: message, tone: .error) { model.bannerMessage = nil }
          .padding(.top, 8)
          .transition(.move(edge: .top).combined(with: .opacity))
      } else if let message = model.protocolWarningMessage {
        NoticeBanner(message: message, tone: .warning) { model.protocolWarningMessage = nil }
          .padding(.top, 8)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .overlay(alignment: .bottom) {
      if let acknowledgement = model.reportAcknowledgement {
        UndoNotice(
          message: acknowledgement.message,
          undo: { withAnimation(.snappy) { model.undoLastReportAcknowledgement() } },
          dismiss: { withAnimation(.snappy) { model.dismissReportAcknowledgement() } }
        )
        .padding(.bottom, 18)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.snappy, value: model.reportAcknowledgement)
    .onChange(of: model.searchFocusRequest) { _, _ in searchFocused = true }
    .onMoveCommand { model.moveSelection($0) }
    .frame(minWidth: 900, minHeight: 600)
  }

  private var workspaceHeader: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 3) {
        Text("TASK RADAR / 任务雷达")
          .font(CMFont.mono(10, weight: .semibold))
          .tracking(2)
          .foregroundStyle(CMColor.muted)
        Text(
          model.selectedProjectID.flatMap { id in model.board.projects.first { $0.id == id }?.name }
            ?? "全部项目"
        )
        .font(CMFont.display(27, weight: .bold))
        .foregroundStyle(CMColor.ink)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 5) {
        ConnectionBadge(status: model.connection)
        Text(model.connection.isOnline ? "状态已同步" : "等待连接")
          .font(CMFont.mono(9))
          .foregroundStyle(CMColor.muted)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 14)
    .background(CMColor.warmPaper.opacity(0.93))
    .overlay(alignment: .bottom) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }
  }

  private var metricsStrip: some View {
    HStack(spacing: 0) {
      metric("办理中", value: model.scopedRunningCount, color: CMColor.workOrange, index: "01")
      metric("举手", value: model.scopedAttentionCount, color: CMColor.raiseRed, index: "02")
      metric(
        "完成未阅", value: model.scopedCompletedUnreadCount, color: CMColor.reportGreen, index: "03")
      metric("历史档案", value: model.scopedHistoryCount, color: CMColor.muted, index: "04")
    }
    .background(CMColor.porcelain.opacity(0.88))
    .overlay(alignment: .bottom) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }
  }

  private func metric(_ title: String, value: Int, color: Color, index: String) -> some View {
    HStack(spacing: 10) {
      Text(index).font(CMFont.mono(9)).foregroundStyle(CMColor.muted.opacity(0.7))
      Text("\(value)").font(CMFont.display(21, weight: .bold)).foregroundStyle(CMColor.ink)
      Circle().fill(color).frame(width: 6, height: 6)
      Text(title).font(CMFont.body(11, weight: .medium)).foregroundStyle(CMColor.muted)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .overlay(alignment: .trailing) { Rectangle().fill(CMColor.hairline).frame(width: 0.5) }
  }

  private var filterBar: some View {
    @Bindable var model = model
    return HStack(spacing: 12) {
      Picker("状态", selection: $model.filter) {
        ForEach(TaskFilter.allCases) { filter in Text(filter.title).tag(filter) }
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: 480)

      Spacer()

      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass").foregroundStyle(CMColor.muted)
        TextField("搜索职员、任务、项目或工号", text: $model.searchText)
          .textFieldStyle(.plain)
          .font(CMFont.body(12))
          .focused($searchFocused)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .frame(width: 280)
      .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 7))
      .overlay(RoundedRectangle(cornerRadius: 7).stroke(CMColor.hairline, lineWidth: 0.7))
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .background(CMColor.warmPaper.opacity(0.88))
  }

  private var taskBoard: some View {
    ScrollView {
      if model.filteredTasks.isEmpty {
        ContentUnavailableView {
          Label(emptyStateTitle, systemImage: "rectangle.3.group")
        } description: {
          Text(emptyStateDescription)
        } actions: {
          if model.canManageTasks && model.filter != .history {
            Button("交办任务") { model.isNewTaskPresented = true }
          } else if !model.connection.isOnline {
            Button("重新连接") { model.retry() }
          }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
      } else {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16)], spacing: 16
        ) {
          ForEach(model.filteredTasks) { task in
            ZStack(alignment: .bottomTrailing) {
              Button {
                model.selectTask(task)
              } label: {
                TaskCardView(task: task, selected: model.selectedTaskID == task.id)
              }
              .buttonStyle(.plain)
              .simultaneousGesture(
                TapGesture(count: 2).onEnded { model.openInCodex(task) }
              )
              .contextMenu {
                Button("在 Codex 中打开", systemImage: "arrow.up.right.square") {
                  model.openInCodex(task)
                }
              }

              Button {
                model.openInCodex(task)
              } label: {
                Image(systemName: "arrow.up.right.square")
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(CMColor.muted)
                  .frame(width: 24, height: 24)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .help("在 Codex 中打开")
              .accessibilityLabel("在 Codex 中打开 \(task.title)")
              .padding(.trailing, 8)
              .padding(.bottom, 8)
            }
          }
        }
        .padding(20)
        .animation(.snappy(duration: 0.25), value: model.filteredTasks.map(\.id))
      }
    }
  }

  private var emptyStateTitle: String {
    switch model.filter {
    case .all: "还没有可显示的会话"
    case .history: "暂无历史档案"
    default: "当前筛选没有会话"
    }
  }

  private var emptyStateDescription: String {
    guard model.connection.isOnline else { return model.connection.detail }
    return switch model.filter {
    case .all: "已有 Codex 会话和工作台职员卡都会出现在这里。"
    case .history: "其他 Codex 客户端保存的会话会以只读档案显示。"
    default: "可以切换到“全部会话”，或交办一个新任务。"
    }
  }
}

private enum NoticeTone {
  case error
  case warning

  var color: Color {
    switch self {
    case .error: CMColor.raiseRed
    case .warning: CMColor.workOrange
    }
  }

  var icon: String {
    switch self {
    case .error: "exclamationmark.triangle.fill"
    case .warning: "exclamationmark.circle.fill"
    }
  }
}

private struct NoticeBanner: View {
  let message: String
  let tone: NoticeTone
  let dismiss: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: tone.icon)
      Text(message).font(CMFont.body(12, weight: .medium)).lineLimit(2)
      Button(action: dismiss) { Image(systemName: "xmark") }.buttonStyle(.plain)
    }
    .foregroundStyle(tone.color)
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.color.opacity(0.4), lineWidth: 1))
    .shadow(color: CMColor.ink.opacity(0.12), radius: 8, y: 4)
  }
}

private struct UndoNotice: View {
  let message: String
  let undo: () -> Void
  let dismiss: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(CMColor.reportGreen)
      Text(message)
        .font(CMFont.body(12, weight: .medium))
        .lineLimit(1)
      Button("撤销", action: undo)
        .buttonStyle(.borderless)
        .font(CMFont.body(12, weight: .bold))
        .foregroundStyle(CMColor.reportGreen)
      Divider().frame(height: 16)
      Button(action: dismiss) { Image(systemName: "xmark") }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭提示")
    }
    .foregroundStyle(CMColor.ink)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9)
        .stroke(CMColor.reportGreen.opacity(0.35), lineWidth: 1)
    )
    .shadow(color: CMColor.ink.opacity(0.14), radius: 10, y: 5)
  }
}
