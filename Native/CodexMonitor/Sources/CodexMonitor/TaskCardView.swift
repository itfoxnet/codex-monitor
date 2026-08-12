import CodexMonitorCore
import SwiftUI

struct TaskCardView: View {
  let task: TaskRecord
  let selected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Rectangle().fill(task.displayStatus.color).frame(height: 3)

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
            Text("柜台 \(StaffIdentity.deskNumber(for: task.id)) · \(task.projectName)")
              .font(CMFont.mono(9))
              .foregroundStyle(CMColor.muted)
          }
          Spacer(minLength: 0)
        }

        Text(task.title)
          .font(CMFont.body(13, weight: .semibold))
          .foregroundStyle(CMColor.ink)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack {
          StatusPill(status: task.displayStatus)
          Spacer()
          Text(RelativeTimeText.string(since: task.updatedAt))
            .font(CMFont.mono(9))
            .foregroundStyle(CMColor.muted)
        }

        HStack(spacing: 8) {
          if let branch = task.branch, !branch.isEmpty {
            Label(branch, systemImage: "arrow.triangle.branch")
              .lineLimit(1)
          }
          Spacer(minLength: 0)
          Text(
            task.ownership == .hostedLive
              ? "SERVER" : task.isExternallyObserved ? "OBSERVED" : "ARCHIVE")
          Color.clear.frame(width: 22, height: 18)
        }
        .font(CMFont.mono(9))
        .foregroundStyle(CMColor.muted)
      }
      .padding(14)
    }
    .background(CMColor.porcelain)
    .clipShape(RoundedRectangle(cornerRadius: 9))
    .overlay(
      RoundedRectangle(cornerRadius: 9)
        .stroke(selected ? CMColor.ink : CMColor.hairline, lineWidth: selected ? 1.5 : 0.7)
    )
    .shadow(color: CMColor.ink.opacity(0.06), radius: 8, y: 4)
    .overlay(alignment: .topTrailing) {
      if task.displayStatus == .needsApproval || task.displayStatus == .needsInput {
        Image(systemName: "hand.raised.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(CMColor.porcelain)
          .frame(width: 32, height: 32)
          .background(CMColor.raiseRed, in: RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(CMColor.porcelain, lineWidth: 3))
          .offset(x: 7, y: -9)
          .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottomLeading)))
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
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(StaffIdentity.name(for: task.id))，\(task.projectName)，\(task.displayStatus.title)，\(task.title)"
    )
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
