import CodexMonitorCore
import SwiftUI

struct TaskCardView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @State private var isCardHovered = false

  let task: TaskRecord
  let selected: Bool
  let onSelect: () -> Void
  let onOpen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Rectangle().fill(task.displayStatus.color).frame(height: 3)

      Button(action: onSelect) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .top, spacing: 10) {
            statusMedallion
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                Text(StaffIdentity.name(for: task.id))
                  .font(CMFont.body(14, weight: .bold))
                Text("#\(StaffIdentity.shortID(for: task.id))")
                  .font(CMFont.mono(9))
                  .foregroundStyle(CMColor.muted)
              }
              Text(
                "柜台 \(StaffIdentity.deskNumber(for: task.id)) · \(model.preferences.displayProjectName(for: task))"
              )
              .font(CMFont.mono(9))
              .foregroundStyle(CMColor.muted)
              .lineLimit(1)
            }
            Spacer(minLength: 0)
          }

          Text(model.preferences.displayTitle(for: task))
            .font(CMFont.body(13, weight: .semibold))
            .foregroundStyle(CMColor.ink)
            .lineLimit(2)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

          HStack {
            StatusPill(status: task.displayStatus)
            Spacer()
            Text(RelativeTimeText.string(since: task.updatedAt))
              .font(CMFont.mono(9))
              .foregroundStyle(CMColor.muted)
          }
        }
        .contentShape(Rectangle())
        .padding(14)
      }
      .buttonStyle(CMTaskCardButtonStyle(selected: selected))
      .accessibilityLabel(cardAccessibilityLabel)
      .accessibilityHint("按下查看详情")

      Rectangle().fill(CMColor.hairline).frame(height: 0.5)

      HStack(spacing: 8) {
        if let branch = model.preferences.displayBranch(for: task), !branch.isEmpty {
          Group {
            if model.preferences.privacyMode {
              Text(branch)
            } else {
              Label(branch, systemImage: "arrow.triangle.branch")
            }
          }
          .lineLimit(1)
        }
        Spacer(minLength: 0)
        Text(
          task.ownership == .hostedLive
            ? "SERVER" : task.isExternallyObserved ? "OBSERVED" : "ARCHIVE")
        Button(action: onOpen) {
          Image(systemName: "arrow.up.right.square")
            .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(CMIconButtonStyle(tint: CMColor.muted))
        .help("在 Codex 中打开")
        .accessibilityLabel("在 Codex 中打开此会话")
      }
      .font(CMFont.mono(9))
      .foregroundStyle(CMColor.muted)
      .padding(.leading, 14)
      .padding(.trailing, 8)
      .padding(.vertical, 6)
      .frame(minHeight: 40)
    }
    .background(CMColor.porcelain)
    .clipShape(RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9)
        .stroke(
          selected ? CMColor.ink : isCardHovered ? CMColor.ink.opacity(0.48) : CMColor.hairline,
          lineWidth: selected
            ? (contrast == .increased ? 2 : 1.5) : contrast == .increased ? 1.2 : 0.7
        )
    )
    .shadow(
      color: CMColor.ink.opacity(isCardHovered ? (contrast == .increased ? 0.2 : 0.13) : 0.06),
      radius: isCardHovered ? 11 : 8,
      y: isCardHovered ? 5 : 4
    )
    .overlay(alignment: .topTrailing) {
      if task.displayStatus == .needsApproval || task.displayStatus == .needsInput {
        Image(systemName: "hand.raised.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(CMColor.porcelain)
          .frame(width: 32, height: 32)
          .background(CMColor.raiseRed, in: RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(CMColor.porcelain, lineWidth: 3))
          .offset(x: 7, y: -9)
          .transition(
            reduceMotion
              ? .opacity : .opacity.combined(with: .scale(scale: 0.85, anchor: .bottomLeading)))
      } else if task.displayStatus == .completedUnseen {
        Image(systemName: "hand.raised.fill")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(CMColor.reportGreen)
          .frame(width: 32, height: 32)
          .background(CMColor.porcelain, in: RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
              CMColor.reportGreen.opacity(0.35), lineWidth: 1)
          )
          .offset(x: 7, y: -9)
      }
    }
    .contentShape(RoundedRectangle(cornerRadius: 9))
    .onHover { isCardHovered = $0 }
    .animation(reduceMotion ? nil : .easeOut(duration: CMMotion.hover), value: isCardHovered)
    .contextMenu {
      Button("在 Codex 中打开", systemImage: "arrow.up.right.square", action: onOpen)
    }
  }

  private var cardAccessibilityLabel: String {
    let identity = "\(StaffIdentity.name(for: task.id))，工号 \(StaffIdentity.shortID(for: task.id))"
    return
      "\(identity)，\(model.preferences.displayProjectName(for: task))，\(task.displayStatus.title)，\(model.preferences.displayTitle(for: task))，更新于 \(RelativeTimeText.string(since: task.updatedAt))"
  }

  private var statusMedallion: some View {
    Image(systemName: task.displayStatus.symbol)
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(task.displayStatus.color)
      .frame(width: 34, height: 34)
      .background(task.displayStatus.color.opacity(0.08), in: Circle())
      .overlay(Circle().stroke(task.displayStatus.color.opacity(0.35), lineWidth: 1))
  }
}
