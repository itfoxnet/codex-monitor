import CodexMonitorCore
import SwiftUI

struct TaskDetailView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Group {
      if let task = model.selectedTask {
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            identity(task)
            statusSection(task)
            if task.ownership == .historyOnly {
              TakeOverPanel(task: task)
            } else {
              ForEach(task.openAttentions) { request in
                ApprovalPanel(request: request)
              }
            }
            if let summary = task.lastSummary, !summary.isEmpty {
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
      } else {
        ContentUnavailableView("选择一名职员", systemImage: "person.crop.rectangle")
      }
    }
  }

  private func identity(_ task: TaskRecord) -> some View {
    VStack(alignment: .leading, spacing: 12) {
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
        Spacer()
        StatusPill(status: task.displayStatus)
      }
      Text(task.title)
        .font(CMFont.body(14, weight: .semibold))
        .foregroundStyle(CMColor.ink)
        .textSelection(.enabled)
    }
  }

  private func statusSection(_ task: TaskRecord) -> some View {
    section("工作单", symbol: "doc.text") {
      detailRow("项目", value: task.projectName)
      detailRow(
        "来源",
        value: task.ownership == .hostedLive
          ? "工作台 App Server" : task.isExternallyObserved ? "其他 Codex 客户端（本机观察）" : "其他 Codex 客户端档案"
      )
      detailRow("原始状态", value: task.rawStatus)
      if let branch = task.branch { detailRow("分支", value: branch) }
      detailRow("更新时间", value: task.updatedAt.formatted(date: .abbreviated, time: .standard))
      detailRow("Thread", value: task.id)
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
        withAnimation(.snappy) { model.markCompletedSeen(task) }
      } label: {
        Label("确认已阅", systemImage: "checkmark.circle")
      }
      .buttonStyle(.borderedProminent)
      .tint(CMColor.reportGreen)
    }
    if task.displayStatus == .running, task.activeTurnID != nil {
      Button(role: .destructive) {
        Task { await model.interrupt(task) }
      } label: {
        Label("中断当前办理", systemImage: "stop.circle")
      }
      .buttonStyle(.bordered)
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

  private func detailRow(_ label: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label).foregroundStyle(CMColor.muted).frame(width: 70, alignment: .leading)
      Text(value).foregroundStyle(CMColor.ink).textSelection(.enabled)
      Spacer(minLength: 0)
    }
    .font(CMFont.mono(10))
  }
}

private struct ApprovalPanel: View {
  @Environment(AppModel.self) private var model
  let request: AttentionRequest
  @State private var revealSensitive = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(request.title, systemImage: "hand.raised.fill")
          .font(CMFont.body(13, weight: .bold))
          .foregroundStyle(CMColor.raiseRed)
        Spacer()
        Text(request.state == .responding ? "正在提交" : "等待处理")
          .font(CMFont.mono(9))
          .foregroundStyle(CMColor.muted)
      }

      if let reason = request.reason, !reason.isEmpty {
        Text(reason).font(CMFont.body(12)).foregroundStyle(CMColor.ink)
      }

      if request.kind == .userInput {
        UserInputApprovalView(request: request)
      } else {
        if request.command != nil || request.workingDirectory != nil
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
            Text("查看操作范围").font(CMFont.body(11, weight: .medium))
          }
        }

        HStack(spacing: 8) {
          Button("一次允许") {
            Task { await model.decide(request, decision: .accept) }
          }
          .buttonStyle(.borderedProminent)
          .tint(CMColor.reportGreen)

          Button("拒绝") {
            Task { await model.decide(request, decision: .decline) }
          }
          .buttonStyle(.bordered)

          if request.kind == .commandApproval || request.kind == .fileApproval {
            Button("取消任务", role: .destructive) {
              Task { await model.decide(request, decision: .cancel) }
            }
            .buttonStyle(.borderless)
          }
        }
        .disabled(request.state != .open)
      }
    }
    .padding(14)
    .background(CMColor.raiseRed.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(CMColor.raiseRed.opacity(0.35), lineWidth: 1))
  }
}

private struct UserInputApprovalView: View {
  @Environment(AppModel.self) private var model
  let request: AttentionRequest
  @State private var answers: [String: String] = [:]
  @State private var selections: [String: String] = [:]
  private let otherSelection = "__codex_monitor_other__"

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
                get: { selections[question.id] ?? question.options.first?.label ?? "" },
                set: { selections[question.id] = $0 }
              )
            ) {
              ForEach(question.options) { option in
                Text(option.label).tag(option.label)
              }
              if question.allowsOther { Text("其他…").tag(otherSelection) }
            }
            .labelsHidden()
            if question.allowsOther && selections[question.id] == otherSelection {
              answerField(for: question)
            }
          } else {
            answerField(for: question)
          }
        }
      }

      Button("提交回答") {
        let mapped = Dictionary(
          uniqueKeysWithValues: request.questions.map { question in
            let selection = selections[question.id] ?? question.options.first?.label
            let value =
              selection == otherSelection
              ? answers[question.id] ?? "" : selection ?? answers[question.id] ?? ""
            return (question.id, [value])
          })
        Task { await model.answer(request, answers: mapped) }
      }
      .buttonStyle(.borderedProminent)
      .tint(CMColor.reportGreen)
      .disabled(request.state != .open || !hasCompleteAnswers)
    }
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
      let selection = selections[question.id] ?? question.options.first?.label ?? ""
      if selection == otherSelection {
        return !(answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
      return !selection.isEmpty
    }
  }
}

private struct TakeOverPanel: View {
  @Environment(AppModel.self) private var model
  let task: TaskRecord
  @State private var prompt = "继续这个任务，并先确认当前仓库状态。"

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(
        task.isExternallyObserved ? "正在观察其他 Codex 客户端" : "这是一份历史档案",
        systemImage: task.isExternallyObserved ? "eye" : "archivebox"
      )
      .font(CMFont.body(13, weight: .bold))
      Text(
        task.isExternallyObserved
          ? "办理、完成、中止和失败状态来自本机会话日志；授权申请仍需回到原 Codex 客户端处理。"
          : "只有接管后的新一轮工作由本工作台实时管理。请避免同时在其他 Codex 客户端继续同一任务。"
      )
      .font(CMFont.body(11))
      .foregroundStyle(CMColor.muted)
      TextEditor(text: $prompt)
        .font(CMFont.body(12))
        .frame(minHeight: 70)
        .padding(6)
        .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(CMColor.hairline, lineWidth: 0.7))
      Button("接管并继续") {
        Task { _ = await model.takeOver(task, prompt: prompt) }
      }
      .buttonStyle(.borderedProminent)
      .tint(CMColor.ink)
      .disabled(
        model.isBusy || !model.canManageTasks
          || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .padding(14)
    .background(CMColor.workOrange.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9).stroke(CMColor.workOrange.opacity(0.3), lineWidth: 1))
  }
}
