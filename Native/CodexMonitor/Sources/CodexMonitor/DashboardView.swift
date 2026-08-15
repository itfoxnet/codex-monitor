import CodexMonitorCore
import SwiftUI

struct DashboardView: View {
  @Environment(AppModel.self) private var model
  @Environment(AppCoordinator.self) private var coordinator
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var searchFocused: Bool
  @State private var searchHovered = false

  var body: some View {
    @Bindable var model = model

    GeometryReader { geometry in
      let usesCompactDetail = geometry.size.width < 1_180
      let gridColumns = AdaptiveTaskGridPolicy.columnCount(
        windowWidth: geometry.size.width,
        inspectorWidth: !usesCompactDetail && model.selectedTaskID != nil ? 380 : 0
      )

      NavigationSplitView {
        ProjectSidebar()
          .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 320)
      } detail: {
        if usesCompactDetail, model.selectedTaskID != nil {
          compactTaskDetail
            .navigationTitle("任务详情")
        } else {
          ZStack {
            OperationsGridBackground()
            GeometryReader { contentGeometry in
              let contentWidth = contentGeometry.size.width
              VStack(spacing: 0) {
                workspaceHeader
                metricsStrip(contentWidth: contentWidth)
                filterBar(contentWidth: contentWidth)
                taskBoard(gridColumns: gridColumns)
              }
            }
          }
          .navigationTitle("工作台")
        }
      }
      .navigationSplitViewStyle(.balanced)
      .inspector(
        isPresented: Binding(
          get: { !usesCompactDetail && model.selectedTaskID != nil },
          set: { presented in
            if !presented, !usesCompactDetail { model.dismissTaskSelection() }
          }
        )
      ) {
        TaskDetailView()
          .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
      }
      .toolbar {
        ToolbarItemGroup {
          Button {
            coordinator.present(.newTask)
          } label: {
            Label("交办任务", systemImage: "plus")
          }
          .disabled(!model.canManageTasks)

          Button {
            Task { await model.refreshFromUI() }
          } label: {
            if model.refreshPhase.isRefreshing {
              ProgressView()
                .controlSize(.small)
                .accessibilityLabel("正在核对状态")
            } else {
              Label("刷新", systemImage: "arrow.clockwise")
            }
          }
          .help(model.refreshPhase.isRefreshing ? "正在核对所有会话状态" : "立即核对所有会话状态")
          .disabled(!model.connection.isOnline || model.refreshPhase.isRefreshing)

          Button {
            coordinator.present(.settings)
          } label: {
            Label("设置", systemImage: "slider.horizontal.3")
          }
        }
      }
      .sheet(
        item: Binding(
          get: { coordinator.modalRoute },
          set: { coordinator.modalRoute = $0 }
        )
      ) { route in
        switch route {
        case .newTask: NewTaskSheet()
        case .settings: SettingsView()
        }
      }
      .overlay(alignment: .top) {
        if let message = model.bannerMessage {
          Group {
            if case .failed = model.refreshPhase {
              NoticeBanner(
                message: message,
                tone: .error,
                actionTitle: "重试",
                action: model.retryRefresh
              ) { model.dismissRefreshFailure() }
            } else {
              NoticeBanner(message: message, tone: .error) { model.bannerMessage = nil }
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 12)
          .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        } else if let message = model.protocolWarningMessage {
          NoticeBanner(message: message, tone: .warning) { model.protocolWarningMessage = nil }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        }
      }
      .overlay(alignment: .bottom) {
        if let acknowledgement = model.reportAcknowledgement {
          UndoNotice(
            message: acknowledgement.message,
            undo: {
              withAnimation(reduceMotion ? nil : .snappy) { model.undoLastReportAcknowledgement() }
            },
            dismiss: {
              withAnimation(reduceMotion ? nil : .snappy) { model.dismissReportAcknowledgement() }
            }
          )
          .padding(.horizontal, 16)
          .padding(.bottom, 18)
          .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(reduceMotion ? nil : .snappy, value: model.reportAcknowledgement)
      .onChange(of: model.searchFocusRequest) { _, _ in
        if usesCompactDetail, model.selectedTaskID != nil {
          model.dismissTaskSelection()
          Task { @MainActor in
            await Task.yield()
            searchFocused = true
          }
        } else {
          searchFocused = true
        }
      }
    }
    .frame(minWidth: 900, minHeight: 600)
  }

  private var compactTaskDetail: some View {
    VStack(spacing: 0) {
      HStack {
        Button {
          model.dismissTaskSelection()
        } label: {
          Label("返回工作台", systemImage: "chevron.left")
        }
        .buttonStyle(.bordered)
        .keyboardShortcut(.cancelAction)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .background(CMColor.warmPaper)
      .overlay(alignment: .bottom) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }

      TaskDetailView()
    }
  }

  private var workspaceHeader: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 3) {
        Text("TASK RADAR / 任务雷达")
          .font(CMFont.mono(10, weight: .semibold))
          .tracking(2)
          .foregroundStyle(CMColor.muted)
        Text(
          model.selectedProjectID.flatMap { id in
            guard !model.preferences.privacyMode else {
              return "保密项目 · \(StaffIdentity.privateReference(for: id))"
            }
            return model.board.projects.first { $0.id == id }?.name
          } ?? "全部项目"
        )
        .font(CMFont.display(27, weight: .bold))
        .foregroundStyle(CMColor.ink)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 5) {
        ConnectionBadge(status: model.connection)
        TimelineView(.periodic(from: .now, by: 30)) { context in
          Text(dataFreshnessText(at: context.date))
            .font(CMFont.mono(9))
            .foregroundStyle(
              dataFreshnessNeedsAttention(at: context.date) ? CMColor.raiseRed : CMColor.muted)
        }
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 14)
    .background(CMColor.warmPaper.opacity(0.93))
    .overlay(alignment: .bottom) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }
  }

  private func dataFreshnessText(at now: Date) -> String {
    guard model.connection.isOnline else { return "等待连接" }
    guard !model.statusNeedsVerification else { return "状态待核对" }
    guard let date = model.lastSuccessfulRefreshAt else { return "状态待核对" }
    if now.timeIntervalSince(date) > 90 {
      return "上次同步 \(date.formatted(date: .omitted, time: .shortened)) · 已过期"
    }
    return "最近同步 \(date.formatted(date: .omitted, time: .shortened))"
  }

  private func dataFreshnessNeedsAttention(at now: Date) -> Bool {
    guard model.connection.isOnline else { return false }
    guard !model.statusNeedsVerification, let date = model.lastSuccessfulRefreshAt else {
      return true
    }
    return now.timeIntervalSince(date) > 90
  }

  private func metricsStrip(contentWidth: CGFloat) -> some View {
    let layout = DashboardResponsivePolicy.metricsLayout(contentWidth: contentWidth)
    return Group {
      switch layout {
      case .spacious, .compact:
        HStack(spacing: 0) {
          metric(
            "办理中", value: model.scopedRunningCount, color: CMColor.workOrange, index: "01",
            position: 0, layout: layout)
          metric(
            "举手", value: model.scopedAttentionCount, color: CMColor.raiseRed, index: "02",
            position: 1, layout: layout)
          metric(
            "未阅汇报", value: model.scopedCompletedUnreadCount, color: CMColor.reportGreen,
            index: "03", position: 2, layout: layout)
          metric(
            "历史档案", value: model.scopedHistoryCount, color: CMColor.muted, index: "04",
            position: 3, layout: layout)
        }
      case .stacked:
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            metric(
              "办理中", value: model.scopedRunningCount, color: CMColor.workOrange, index: "01",
              position: 0, layout: layout)
            metric(
              "举手", value: model.scopedAttentionCount, color: CMColor.raiseRed, index: "02",
              position: 1, layout: layout)
          }
          HStack(spacing: 0) {
            metric(
              "未阅汇报", value: model.scopedCompletedUnreadCount, color: CMColor.reportGreen,
              index: "03", position: 2, layout: layout)
            metric(
              "历史档案", value: model.scopedHistoryCount, color: CMColor.muted, index: "04",
              position: 3, layout: layout)
          }
        }
      }
    }
    .background(CMColor.porcelain.opacity(0.88))
    .overlay(alignment: .bottom) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }
  }

  private func metric(
    _ title: String,
    value: Int,
    color: Color,
    index: String,
    position: Int,
    layout: DashboardMetricsLayout
  ) -> some View {
    let isSpacious = layout == .spacious
    let isCompact = layout == .compact
    return HStack(spacing: isSpacious ? 8 : 6) {
      if !isCompact {
        Text(index).font(CMFont.mono(9)).foregroundStyle(CMColor.muted.opacity(0.7))
      }
      Text("\(value)")
        .font(CMFont.display(isSpacious ? 21 : 18, weight: .bold))
        .foregroundStyle(CMColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Circle().fill(color).frame(width: 6, height: 6)
      Text(title)
        .font(CMFont.body(11, weight: .medium))
        .foregroundStyle(CMColor.muted)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, isSpacious ? 12 : isCompact ? 9 : 10)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .overlay(alignment: .trailing) {
      if DashboardResponsivePolicy.showsMetricSeparator(at: position, layout: layout) {
        Rectangle().fill(CMColor.hairline).frame(width: 0.5)
      }
    }
  }

  private func filterBar(contentWidth: CGFloat) -> some View {
    @Bindable var model = model
    let layout = DashboardResponsivePolicy.filterLayout(contentWidth: contentWidth)
    return Group {
      switch layout {
      case .inlineSegmented:
        HStack(spacing: 12) {
          segmentedStatusPicker
            .frame(maxWidth: .infinity)
          Spacer(minLength: 8)
          searchField
            .frame(minWidth: 220, idealWidth: 280, maxWidth: 320)
        }
      case .stackedSegmented:
        VStack(alignment: .leading, spacing: 8) {
          segmentedStatusPicker
            .frame(maxWidth: .infinity)
          searchField
            .frame(maxWidth: .infinity)
        }
      case .stackedMenu:
        VStack(alignment: .leading, spacing: 8) {
          menuStatusPicker
            .frame(maxWidth: .infinity)
          searchField
            .frame(maxWidth: .infinity)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .background(CMColor.warmPaper.opacity(0.88))
  }

  private var segmentedStatusPicker: some View {
    @Bindable var model = model
    return Picker("状态", selection: $model.filter) {
      ForEach(TaskFilter.allCases) { filter in Text(filter.title).tag(filter) }
    }
    .pickerStyle(.segmented)
  }

  private var menuStatusPicker: some View {
    @Bindable var model = model
    return LabeledContent("会话状态") {
      Picker("会话状态", selection: $model.filter) {
        ForEach(TaskFilter.allCases) { filter in Text(filter.title).tag(filter) }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .font(CMFont.caption)
  }

  private var searchField: some View {
    @Bindable var model = model
    return HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(CMColor.muted)
        .accessibilityHidden(true)
      TextField("搜索职员、任务、项目或工号", text: $model.searchText)
        .textFieldStyle(.plain)
        .font(CMFont.body(12))
        .focused($searchFocused)
      if !model.searchText.isEmpty {
        Button {
          model.searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(CMIconButtonStyle(tint: CMColor.muted))
        .cmKeyboardFocusable()
        .help("清除搜索")
        .accessibilityLabel("清除搜索")
      }
    }
    .padding(.leading, 10)
    .padding(.trailing, 6)
    .padding(.vertical, 7)
    .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 7))
    .overlay(
      RoundedRectangle(cornerRadius: 7)
        .stroke(
          searchFocused
            ? CMColor.focusRing
            : searchHovered ? CMColor.ink.opacity(0.42) : CMColor.hairline,
          lineWidth: searchFocused ? 2 : searchHovered ? 1 : 0.7
        )
    )
    .shadow(
      color: CMColor.ink.opacity(searchHovered && !searchFocused ? 0.07 : 0),
      radius: 4,
      y: 2
    )
    .onHover { searchHovered = $0 }
    .animation(reduceMotion ? nil : .easeOut(duration: CMMotion.hover), value: searchHovered)
    .animation(reduceMotion ? nil : .easeOut(duration: CMMotion.settle), value: searchFocused)
  }

  private func taskBoard(gridColumns: Int) -> some View {
    let visibleTasks = model.filteredTasks
    return ScrollViewReader { proxy in
      ScrollView {
        if visibleTasks.isEmpty {
          ContentUnavailableView {
            Label(emptyStateTitle, systemImage: "rectangle.3.group")
          } description: {
            Text(emptyStateDescription)
          } actions: {
            if !model.searchText.isEmpty {
              Button("清除搜索") { model.searchText = "" }
            } else if model.canManageTasks && model.filter != .history {
              Button("交办任务") { coordinator.present(.newTask) }
            } else if !model.connection.isOnline {
              Button("重新连接") { model.retry() }
            }
          }
          .frame(maxWidth: .infinity, minHeight: 360)
        } else {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 16)], spacing: 16
          ) {
            ForEach(visibleTasks) { task in
              TaskCardView(
                task: task,
                selected: model.selectedTaskID == task.id,
                onSelect: {
                  model.selectTask(task)
                },
                onOpen: { model.openInCodex(task) }
              )
              .id(task.id)
            }
          }
          .padding(20)
          .animation(
            reduceMotion || visibleTasks.count > 80 ? nil : .snappy(duration: 0.2),
            value: visibleTasks.map(\.id)
          )
        }
      }
      .onChange(of: model.selectedTaskID) { _, taskID in
        guard let taskID else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: CMMotion.settle)) {
          proxy.scrollTo(taskID, anchor: .center)
        }
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
  var actionTitle: String?
  var action: (() -> Void)?
  let dismiss: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: tone.icon)
      Text(message)
        .font(CMFont.body(12, weight: .medium))
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
      if let actionTitle, let action {
        Button(actionTitle, action: action)
          .buttonStyle(.bordered)
          .tint(tone.color)
          .accessibilityHint("重新核对全部会话状态")
      }
      Button(action: dismiss) {
        Image(systemName: "xmark")
      }
      .buttonStyle(CMIconButtonStyle(tint: tone.color))
      .cmKeyboardFocusable()
      .help("关闭提示")
      .accessibilityLabel("关闭提示")
    }
    .foregroundStyle(tone.color)
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .frame(maxWidth: 600)
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
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
      Button("撤销", action: undo)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(CMFont.body(12, weight: .bold))
        .foregroundStyle(CMColor.reportGreen)
      Divider().frame(height: 16)
      Button(action: dismiss) { Image(systemName: "xmark") }
        .buttonStyle(CMIconButtonStyle(tint: CMColor.muted))
        .cmKeyboardFocusable()
        .help("关闭提示")
        .accessibilityLabel("关闭提示")
    }
    .foregroundStyle(CMColor.ink)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(maxWidth: 600)
    .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9)
        .stroke(CMColor.reportGreen.opacity(0.35), lineWidth: 1)
    )
    .shadow(color: CMColor.ink.opacity(0.14), radius: 10, y: 5)
  }
}
