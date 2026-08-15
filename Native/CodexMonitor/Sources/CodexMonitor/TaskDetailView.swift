import CodexMonitorCore
import SwiftUI

struct TaskDetailView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var taskPendingInterruption: TaskRecord?

  var body: some View {
    Group {
      if let task = model.selectedTask {
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            identity(task)
            statusSection(task)
            if task.isExternallyObserved {
              ObservedSessionPanel()
            } else if task.ownership == .historyOnly {
              TakeOverPanel(task: task)
            } else {
              ForEach(task.openAttentions) { request in
                ApprovalPanel(request: request)
              }
            }
            if let summary = model.preferences.displaySummary(for: task), !summary.isEmpty {
              section("最近汇报", symbol: "text.alignleft") {
                Text(summary)
                  .font(CMFont.body(12))
                  .textSelection(.enabled)
                  .lineSpacing(3)
              }
            }
            actions(task)
          }
          .padding(20)
        }
        .background(CMColor.warmPaper.opacity(0.6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("任务详情")
      } else {
        ContentUnavailableView("选择一名职员", systemImage: "person.crop.rectangle")
      }
    }
    .confirmationDialog(
      "中断当前办理？",
      isPresented: Binding(
        get: { taskPendingInterruption != nil },
        set: { if !$0 { taskPendingInterruption = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("中断办理", role: .destructive) {
        guard let task = taskPendingInterruption else { return }
        taskPendingInterruption = nil
        Task {
          _ = await model.interrupt(task)
        }
      }
      Button("继续办理", role: .cancel) { taskPendingInterruption = nil }
    } message: {
      Text("职员会停止当前这一轮工作；已经写入的文件不会自动撤销。")
    }
  }

  private func identity(_ task: TaskRecord) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      ViewThatFits(in: .horizontal) {
        identityRow(task)
        VStack(alignment: .leading, spacing: 10) {
          identityCore(task)
          StatusPill(status: task.displayStatus)
        }
      }
      Text(model.preferences.displayTitle(for: task))
        .font(CMFont.body(14, weight: .semibold))
        .foregroundStyle(CMColor.ink)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(StaffIdentity.name(for: task.id))，工号 \(StaffIdentity.shortID(for: task.id))，\(task.displayStatus.title)，\(model.preferences.displayTitle(for: task))"
    )
  }

  private func identityRow(_ task: TaskRecord) -> some View {
    HStack(alignment: .top, spacing: 12) {
      identityCore(task)
      Spacer(minLength: 8)
      StatusPill(status: task.displayStatus)
    }
  }

  private func identityCore(_ task: TaskRecord) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: task.displayStatus.symbol)
        .font(.system(size: 19, weight: .semibold))
        .foregroundStyle(task.displayStatus.color)
        .frame(width: 44, height: 44)
        .background(task.displayStatus.color.opacity(0.08), in: Circle())
        .overlay(Circle().stroke(task.displayStatus.color.opacity(0.3), lineWidth: 1))
      VStack(alignment: .leading, spacing: 3) {
        Text(StaffIdentity.name(for: task.id))
          .font(CMFont.display(20, weight: .bold))
        Text(
          "工号 \(StaffIdentity.shortID(for: task.id)) · 柜台 \(StaffIdentity.deskNumber(for: task.id))"
        )
        .font(CMFont.mono(10))
        .foregroundStyle(CMColor.muted)
      }
    }
  }

  private func statusSection(_ task: TaskRecord) -> some View {
    section("工作单", symbol: "doc.text") {
      Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
        detailRow("项目", value: model.preferences.displayProjectName(for: task))
        detailRow(
          "来源",
          value: task.ownership == .hostedLive
            ? "工作台 App Server" : task.isExternallyObserved ? "其他 Codex 客户端（本机观察）" : "其他 Codex 客户端档案"
        )
        detailRow("原始状态", value: task.rawStatus)
        if let branch = model.preferences.displayBranch(for: task) {
          detailRow("分支", value: branch)
        }
        detailRow("更新时间", value: task.updatedAt.formatted(date: .abbreviated, time: .standard))
        detailRow("Thread", value: task.id)
      }
    }
  }

  @ViewBuilder
  private func actions(_ task: TaskRecord) -> some View {
    Button {
      model.openInCodex(task)
    } label: {
      Label("在 Codex 中打开", systemImage: "arrow.up.right.square")
    }
    .buttonStyle(.bordered)

    if task.displayStatus == .completedUnseen {
      Button {
        withAnimation(reduceMotion ? nil : .snappy) { model.markCompletedSeen(task) }
      } label: {
        Label("确认已阅", systemImage: "checkmark.circle")
      }
      .buttonStyle(.borderedProminent)
      .tint(CMColor.reportGreen)
    }
    if task.displayStatus == .running, task.activeTurnID != nil {
      Button(role: .destructive) {
        taskPendingInterruption = task
      } label: {
        if model.isInterrupting(task) {
          HStack(spacing: 7) {
            ProgressView().controlSize(.small)
            Text("正在中断…")
          }
        } else {
          Label("中断当前办理", systemImage: "stop.circle")
        }
      }
      .buttonStyle(.bordered)
      .disabled(model.isInterrupting(task))
    }
  }

  private func section<Content: View>(
    _ title: String,
    symbol: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol)
        .font(CMFont.body(12, weight: .bold))
        .foregroundStyle(CMColor.ink)
      content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(CMColor.hairline, lineWidth: 0.7))
  }

  @ViewBuilder
  private func detailRow(_ label: String, value: String) -> some View {
    GridRow(alignment: .firstTextBaseline) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(label)
            .foregroundStyle(CMColor.muted)
            .frame(width: 70, alignment: .leading)
          detailValue(value, wraps: false)
        }
        VStack(alignment: .leading, spacing: 5) {
          Text(label)
            .foregroundStyle(CMColor.muted)
          detailValue(value, wraps: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .gridCellColumns(2)
    }
    .font(CMFont.mono(10))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label)，\(value)")
  }

  private func detailValue(_ value: String, wraps: Bool) -> some View {
    Text(value)
      .foregroundStyle(CMColor.ink)
      .textSelection(.enabled)
      .lineLimit(nil)
      .fixedSize(horizontal: !wraps, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ApprovalPanel: View {
  @Environment(AppModel.self) private var model
  let request: AttentionRequest
  @State private var revealSensitive: Bool
  @State private var pendingDestructiveDecision: ApprovalDecision?

  init(request: AttentionRequest) {
    self.request = request
    _revealSensitive = State(initialValue: false)
  }

  private var mustRevealBeforeApproval: Bool {
    model.preferences.privacyMode && !revealSensitive
  }

  private var isSubmitting: Bool { model.isSubmitting(request) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(request.title, systemImage: "hand.raised.fill")
          .font(CMFont.body(13, weight: .bold))
          .foregroundStyle(CMColor.raiseRed)
        Spacer()
        if isSubmitting {
          ProgressView()
            .controlSize(.small)
            .accessibilityLabel("正在提交这项请示")
        }
        Text(isSubmitting ? "正在提交" : "等待处理")
          .font(CMFont.caption2)
          .foregroundStyle(CMColor.muted)
      }

      if let reason = request.reason, !reason.isEmpty {
        Text(mustRevealBeforeApproval ? "请求原因已隐藏，查看授权详情后才能允许。" : reason)
          .font(CMFont.body(12))
          .foregroundStyle(CMColor.ink)
          .fixedSize(horizontal: false, vertical: true)
      }

      if let error = model.requestError(for: request) {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(CMFont.caption)
          .foregroundStyle(CMColor.raiseRed)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("提交错误：\(error)")
      }

      if request.kind == .userInput {
        UserInputApprovalView(request: request)
      } else {
        if model.preferences.privacyMode && !revealSensitive {
          VStack(alignment: .leading, spacing: 8) {
            Label("隐私模式隐藏了本次操作范围", systemImage: "eye.slash")
              .font(CMFont.body(11, weight: .semibold))
            Text("请先查看命令、目录和权限范围，再决定是否允许；拒绝和取消任务始终可用。")
              .font(CMFont.body(10))
              .foregroundStyle(CMColor.muted)
              .fixedSize(horizontal: false, vertical: true)
            Button("显示本次授权详情") { revealSensitive = true }
              .buttonStyle(.bordered)
          }
          .accessibilityElement(children: .contain)
        } else if request.command != nil || request.workingDirectory != nil
          || request.requestedPermissions != nil
        {
          DisclosureGroup(isExpanded: $revealSensitive) {
            VStack(alignment: .leading, spacing: 7) {
              if let command = request.command {
                Text(command)
                  .font(CMFont.mono(10))
                  .textSelection(.enabled)
                  .padding(8)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(CMColor.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
              }
              if let cwd = request.workingDirectory {
                Label(cwd, systemImage: "folder")
                  .font(CMFont.mono(9))
                  .textSelection(.enabled)
              }
              if let permissions = request.requestedPermissions {
                Text(permissions.rendered(maxLength: 500))
                  .font(CMFont.mono(9))
                  .textSelection(.enabled)
              }
            }
            .padding(.top, 6)
          } label: {
            Text("查看操作范围")
              .font(CMFont.body(11, weight: .medium))
          }
        }

        HStack(spacing: 8) {
          Button("一次允许") {
            Task { await model.decide(request, decision: .accept) }
          }
          .buttonStyle(.borderedProminent)
          .tint(CMColor.reportGreen)
          .disabled(mustRevealBeforeApproval || request.state != .open || isSubmitting)

          Button("拒绝") {
            Task { await model.decide(request, decision: .decline) }
          }
          .buttonStyle(.bordered)

          if request.kind == .commandApproval || request.kind == .fileApproval {
            Button("取消任务", role: .destructive) {
              pendingDestructiveDecision = .cancel
            }
            .buttonStyle(.bordered)
            .tint(CMColor.raiseRed)
          }
        }
        .disabled(request.state != .open || isSubmitting)
      }
    }
    .padding(14)
    .background(CMColor.raiseRed.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(CMColor.raiseRed.opacity(0.35), lineWidth: 1))
    .onAppear { revealSensitive = !model.preferences.privacyMode }
    .onChange(of: model.preferences.privacyMode) { _, isPrivate in
      revealSensitive = !isPrivate
    }
    .onChange(of: request.id) { _, _ in
      revealSensitive = !model.preferences.privacyMode
    }
    .confirmationDialog(
      "取消这名职员的任务？",
      isPresented: Binding(
        get: { pendingDestructiveDecision != nil },
        set: { if !$0 { pendingDestructiveDecision = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("取消任务", role: .destructive) {
        pendingDestructiveDecision = nil
        Task { await model.decide(request, decision: .cancel) }
      }
      Button("保留任务", role: .cancel) { pendingDestructiveDecision = nil }
    } message: {
      Text("当前办理将被取消；已经写入的文件不会自动撤销。")
    }
  }
}

private struct UserInputApprovalView: View {
  @Environment(AppModel.self) private var model
  let request: AttentionRequest
  @State private var answers: [String: String] = [:]
  @State private var selections: [String: String] = [:]
  private let otherSelection = "__codex_monitor_other__"
  private var isSubmitting: Bool { model.isSubmitting(request) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(request.questions) { question in
        VStack(alignment: .leading, spacing: 6) {
          Text(question.header).font(CMFont.mono(9, weight: .semibold)).foregroundStyle(
            CMColor.muted)
          Text(question.question).font(CMFont.body(12, weight: .semibold))
          if !question.options.isEmpty {
            Picker(
              question.header,
              selection: Binding(
                get: { selections[question.id] ?? "" },
                set: { selections[question.id] = $0 }
              )
            ) {
              Text("请选择…").tag("")
              ForEach(question.options) { option in
                VStack(alignment: .leading, spacing: 2) {
                  Text(option.label)
                  if !option.description.isEmpty {
                    Text(option.description)
                      .font(CMFont.body(11))
                      .foregroundStyle(CMColor.muted)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                }
                .tag(option.label)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                  option.description.isEmpty
                    ? option.label : "\(option.label)，\(option.description)"
                )
              }
              if question.allowsOther { Text("其他…").tag(otherSelection) }
            }
            .pickerStyle(.radioGroup)
            if question.allowsOther && selections[question.id] == otherSelection {
              answerField(for: question)
            }
          } else {
            answerField(for: question)
          }
        }
      }

      Button {
        let mapped = Dictionary(
          uniqueKeysWithValues: request.questions.map { question in
            let selection = selections[question.id]
            let value =
              selection == otherSelection
              ? answers[question.id] ?? "" : selection ?? answers[question.id] ?? ""
            return (question.id, [value])
          })
        Task { await model.answer(request, answers: mapped) }
      } label: {
        if isSubmitting {
          HStack(spacing: 7) {
            ProgressView().controlSize(.small)
            Text("正在提交回答…")
          }
        } else {
          Text("提交回答")
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(CMColor.reportGreen)
      .disabled(request.state != .open || !hasCompleteAnswers || isSubmitting)
      .accessibilityValue(isSubmitting ? "正在提交" : "")
    }
    .disabled(isSubmitting)
  }

  @ViewBuilder
  private func answerField(for question: UserInputQuestion) -> some View {
    let binding = Binding(
      get: { answers[question.id] ?? "" },
      set: { answers[question.id] = $0 }
    )
    if question.isSecret {
      SecureField("输入回答", text: binding)
    } else {
      TextField("输入回答", text: binding)
    }
  }

  private var hasCompleteAnswers: Bool {
    request.questions.allSatisfy { question in
      if question.options.isEmpty {
        return !(answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
      let selection = selections[question.id] ?? ""
      if selection == otherSelection {
        return !(answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
      return !selection.isEmpty
    }
  }
}

private struct TakeOverPanel: View {
  private enum FocusTarget: Hashable {
    case prompt
    case submit
  }

  @Environment(AppModel.self) private var model
  let task: TaskRecord
  @State private var prompt: String
  @FocusState private var focusTarget: FocusTarget?
  @State private var submissionError: String?
  @State private var editorHovered = false

  init(task: TaskRecord) {
    self.task = task
    _prompt = State(initialValue: "继续这个任务，并先确认当前仓库状态。")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("这是一份历史档案", systemImage: "archivebox")
        .font(CMFont.body(13, weight: .bold))
      Text("只有接管后的新一轮工作由本工作台实时管理。请避免同时在其他 Codex 客户端继续同一任务。")
        .font(CMFont.body(11))
        .foregroundStyle(CMColor.muted)
        .fixedSize(horizontal: false, vertical: true)
      TextEditor(text: $prompt)
        .font(CMFont.body(12))
        .frame(minHeight: 90)
        .padding(6)
        .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              submissionError == nil
                ? focusTarget == .prompt
                  ? CMColor.focusRing : editorHovered ? CMColor.ink.opacity(0.42) : CMColor.hairline
                : CMColor.raiseRed,
              lineWidth: focusTarget == .prompt || submissionError != nil ? 1.5 : 0.7
            )
        )
        .accessibilityLabel("接管任务说明")
        .focused($focusTarget, equals: .prompt)
        .disabled(model.isTakingOver(task))
        .opacity(model.isTakingOver(task) ? 0.55 : 1)
        .onHover { editorHovered = model.isTakingOver(task) ? false : $0 }
        .onChange(of: model.isTakingOver(task)) { _, takingOver in
          if takingOver { editorHovered = false }
        }
        .onKeyPress(.tab) {
          focusTarget = .submit
          return .handled
        }
      if let submissionError {
        Text(submissionError)
          .font(CMFont.caption)
          .foregroundStyle(CMColor.raiseRed)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("错误：\(submissionError)")
      }
      Button(model.isTakingOver(task) ? "正在接管…" : "接管并继续") {
        submissionError = nil
        Task {
          if !(await model.takeOver(task, prompt: prompt)) {
            submissionError = model.bannerMessage ?? "未能接管任务，请稍后重试。"
          }
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(CMColor.ink)
      .focused($focusTarget, equals: .submit)
      .disabled(
        model.isTakingOver(task) || !model.canManageTasks
          || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .padding(14)
    .background(CMColor.workOrange.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9).stroke(CMColor.workOrange.opacity(0.3), lineWidth: 1)
    )
    .id(task.id)
    .onChange(of: prompt) { _, _ in submissionError = nil }
  }
}

private struct ObservedSessionPanel: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("正在观察其他 Codex 客户端", systemImage: "eye")
        .font(CMFont.body(13, weight: .bold))
      Text("办理、完成、中止和失败状态来自本机会话日志；授权申请仍需回到原 Codex 客户端处理。")
        .font(CMFont.body(11))
        .foregroundStyle(CMColor.muted)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CMColor.workOrange.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9).stroke(CMColor.workOrange.opacity(0.3), lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
  }
}
