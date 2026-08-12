import AppKit
import SwiftUI

struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var diagnostics = ""
  @State private var showingClearConfirmation = false

  var body: some View {
    @Bindable var preferences = model.preferences

    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("设置与诊断").font(CMFont.display(22, weight: .bold))
        Spacer()
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(CMIconButtonStyle(tint: CMColor.muted))
        .help("关闭设置")
        .accessibilityLabel("关闭设置")
      }
      .padding(20)
      .background(CMColor.warmPaper)
      .overlay(alignment: .bottom) { Rectangle().fill(CMColor.hairline).frame(height: 0.5) }

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          settingsSection("连接", symbol: "point.3.connected.trianglepath.dotted") {
            TextField("Codex 可执行文件", text: $preferences.codexPath)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel("Codex 可执行文件路径")
            HStack {
              Button("选择 Codex…") { chooseCodex() }
              Button("重新连接") { model.retry() }
              Spacer()
              ConnectionBadge(status: model.connection)
            }
            Text("当前版本：\(model.connection.version ?? "未检测")")
              .font(CMFont.mono(10))
              .foregroundStyle(CMColor.muted)
          }

          settingsSection("通知与隐私", symbol: "bell.badge") {
            Toggle("隐藏路径、命令与任务预览", isOn: $preferences.privacyMode)
            Toggle(
              "允许任务通知",
              isOn: Binding(
                get: { preferences.notificationsEnabled },
                set: { value in
                  if value {
                    Task { await model.enableNotifications() }
                  } else {
                    preferences.notificationsEnabled = false
                  }
                }
              ))
            Text(
              preferences.privacyMode
                ? "隐私模式下，通知只提示有新动态，不显示职员、项目、路径、命令或任务预览。"
                : "通知只显示职员名、项目名和状态，不包含完整命令或对话。"
            )
            .font(CMFont.body(10))
            .foregroundStyle(CMColor.muted)
            .fixedSize(horizontal: false, vertical: true)
          }

          settingsSection("诊断", symbol: "stethoscope") {
            HStack {
              Button("刷新诊断") {
                Task { diagnostics = await model.diagnosticsText() }
              }
              Button("复制") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(diagnostics, forType: .string)
              }
              .disabled(diagnostics.isEmpty)
            }
            TextEditor(text: $diagnostics)
              .font(CMFont.mono(9))
              .frame(minHeight: 140)
              .padding(6)
              .background(CMColor.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
              .disabled(true)
              .accessibilityLabel("诊断信息")
          }

          settingsSection("本地数据", symbol: "internaldrive") {
            Text("仅保存托管任务 ID、已阅状态、设置、脱敏快照和最多 100 条不含请求内容的审批摘要。不会保存凭据、完整对话、命令输出或 diff。")
              .font(CMFont.body(11))
              .foregroundStyle(CMColor.muted)
            Button("清除工作台本地数据", role: .destructive) {
              showingClearConfirmation = true
            }
          }
        }
        .padding(20)
      }
    }
    .frame(minWidth: 520, idealWidth: 620, minHeight: 480, idealHeight: 650)
    .background(CMColor.warmPaper)
    .task { diagnostics = await model.diagnosticsText() }
    .confirmationDialog(
      "清除本地数据？",
      isPresented: $showingClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("清除", role: .destructive) { model.clearLocalData() }
      Button("取消", role: .cancel) {}
    } message: {
      Text("不会删除 Codex 任务或项目文件。")
    }
  }

  private func settingsSection<Content: View>(
    _ title: String,
    symbol: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol).font(CMFont.body(13, weight: .bold))
      content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 9))
    .overlay(RoundedRectangle(cornerRadius: 9).stroke(CMColor.hairline, lineWidth: 0.7))
  }

  private func chooseCodex() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.prompt = "选择 Codex"
    if panel.runModal() == .OK, let url = panel.url {
      model.preferences.codexPath = url.path
    }
  }
}
