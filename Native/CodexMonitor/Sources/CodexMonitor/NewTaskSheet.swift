import AppKit
import CodexMonitorCore
import SwiftUI

struct NewTaskSheet: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var draft = TaskDraft()
  @State private var submissionError: String?
  @State private var promptHovered = false
  @FocusState private var promptFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("交办任务").font(CMFont.display(24, weight: .bold))
          Text("为一个项目安排新的 Codex 职员")
            .font(CMFont.body(11))
            .foregroundStyle(CMColor.muted)
        }
        Spacer()
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(CMIconButtonStyle(tint: CMColor.muted))
        .cmKeyboardFocusable()
        .disabled(model.isCreatingTask)
        .help("关闭交办任务")
        .accessibilityLabel("关闭交办任务")
      }
      .padding(20)
      .background(CMColor.warmPaper)
      .overlay(alignment: .bottom) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          field("项目目录", symbol: "folder") {
            HStack {
              TextField("选择一个代码项目", text: $draft.cwd)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("项目目录")
                .disabled(model.isCreatingTask)
              Button("选择…") { chooseDirectory() }
                .disabled(model.isCreatingTask)
            }
          }

          field("任务目标", symbol: "text.bubble") {
            TextEditor(text: $draft.prompt)
              .font(CMFont.body(13))
              .frame(minHeight: 130)
              .padding(8)
              .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 7))
              .overlay(
                RoundedRectangle(cornerRadius: 7)
                  .stroke(
                    submissionError == nil
                      ? promptFocused
                        ? CMColor.focusRing
                        : promptHovered ? CMColor.ink.opacity(0.42) : CMColor.hairline
                      : CMColor.raiseRed,
                    lineWidth: promptFocused || submissionError != nil ? 1.5 : 0.7
                  )
              )
              .accessibilityLabel("任务目标")
              .focused($promptFocused)
              .disabled(model.isCreatingTask)
              .opacity(model.isCreatingTask ? 0.55 : 1)
              .onHover { promptHovered = model.isCreatingTask ? false : $0 }
              .onChange(of: model.isCreatingTask) { _, creating in
                if creating { promptHovered = false }
              }
              .onChange(of: draft.prompt) { _, _ in submissionError = nil }
          }

          field("模型", symbol: "cpu") {
            Picker(
              "模型",
              selection: Binding(
                get: { draft.model ?? "" },
                set: { draft.model = $0.isEmpty ? nil : $0 }
              )
            ) {
              Text("Codex 默认模型").tag("")
              ForEach(model.models) { option in
                Text(option.displayName + (option.isDefault ? " · 默认" : "")).tag(option.id)
              }
            }
            .labelsHidden()
            .frame(maxWidth: 320, alignment: .leading)
            .disabled(model.isCreatingTask)
          }

          HStack(alignment: .top, spacing: 9) {
            Image(systemName: "shield.lefthalf.filled").foregroundStyle(CMColor.reportGreen)
            Text("任务使用 workspace-write 沙箱和 on-request 审批。任何越出当前权限的操作都会让职员举手，不会自动批准。")
              .font(CMFont.body(11))
              .foregroundStyle(CMColor.muted)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(12)
          .background(CMColor.reportGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
          .accessibilityElement(children: .combine)

          if let submissionError {
            Text(submissionError)
              .font(CMFont.body(11))
              .foregroundStyle(CMColor.raiseRed)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityLabel("错误：\(submissionError)")
          }
        }
        .padding(20)
      }

      HStack {
        Spacer()
        Button("取消") { dismiss() }
          .disabled(model.isCreatingTask)
        Button(model.isCreatingTask ? "正在安排…" : "开始办理") {
          Task {
            if await model.createTask(draft) {
              dismiss()
            } else {
              submissionError = model.bannerMessage ?? "任务没有开始，请检查连接和输入。"
            }
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(CMColor.ink)
        .disabled(!draft.isValid || model.isCreatingTask || !model.canManageTasks)
      }
      .padding(20)
      .background(CMColor.warmPaper)
      .overlay(alignment: .top) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }
    }
    .frame(minWidth: 520, idealWidth: 620, minHeight: 480, idealHeight: 610)
    .background(CMColor.warmPaper)
    .interactiveDismissDisabled(model.isCreatingTask)
  }

  private func field<Content: View>(
    _ title: String, symbol: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Label(title, systemImage: symbol)
        .font(CMFont.body(12, weight: .bold))
      content()
    }
  }

  private func chooseDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "选择项目"
    if panel.runModal() == .OK, let url = panel.url { draft.cwd = url.path }
  }
}
