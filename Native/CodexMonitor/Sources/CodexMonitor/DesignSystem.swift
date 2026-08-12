import CodexMonitorCore
import SwiftUI

enum CMColor {
  static let ink = Color(hex: 0x1D211E)
  static let warmPaper = Color(hex: 0xF2EFE6)
  static let porcelain = Color(hex: 0xFCFBF7)
  static let reportGreen = Color(hex: 0x347357)
  static let raiseRed = Color(hex: 0xB84A38)
  static let workOrange = Color(hex: 0x9A5600)
  static let workOrangeOnDark = Color(hex: 0xF0A13A)
  static let muted = Color(hex: 0x606762)
  static let hairline = Color(hex: 0xC9C5BA)
}

enum CMFont {
  static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
  }

  static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .default)
  }

  static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced).monospacedDigit()
  }
}

extension TaskDisplayStatus {
  var color: Color {
    switch self {
    case .needsApproval, .needsInput, .failed: CMColor.raiseRed
    case .completedUnseen, .completedSeen: CMColor.reportGreen
    case .running: CMColor.workOrange
    case .waiting, .interrupted, .unknown, .historyOnly: CMColor.muted
    }
  }

  var symbol: String {
    switch self {
    case .running: "waveform.path.ecg"
    case .waiting: "clock"
    case .needsApproval, .needsInput: "hand.raised.fill"
    case .completedUnseen, .completedSeen: "checkmark"
    case .failed: "exclamationmark.triangle"
    case .interrupted: "stop"
    case .unknown: "questionmark"
    case .historyOnly: "archivebox"
    }
  }
}

extension Color {
  init(hex: UInt32, alpha: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: alpha
    )
  }
}

struct OperationsGridBackground: View {
  var body: some View {
    Canvas { context, size in
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(CMColor.warmPaper))
      var path = Path()
      let step: CGFloat = 32
      for x in stride(from: 0, through: size.width, by: step) {
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
      }
      for y in stride(from: 0, through: size.height, by: step) {
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
      }
      context.stroke(path, with: .color(CMColor.ink.opacity(0.035)), lineWidth: 0.5)
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

struct StatusPill: View {
  let status: TaskDisplayStatus

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: status.symbol)
      Text(status.title)
    }
    .font(CMFont.body(11, weight: .semibold))
    .foregroundStyle(status.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(status.color.opacity(0.09), in: Capsule())
    .overlay(Capsule().stroke(status.color.opacity(0.25), lineWidth: 0.5))
  }
}

struct ConnectionBadge: View {
  let status: ConnectionStatus

  var color: Color {
    switch status.phase {
    case .online: CMColor.reportGreen
    case .unavailable: CMColor.raiseRed
    case .reconnecting, .starting, .initializing, .syncing, .detecting: CMColor.workOrange
    case .disconnected: CMColor.muted
    }
  }

  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(status.phase == .online ? "LIVE" : status.phase.rawValue.uppercased())
        .font(CMFont.mono(10, weight: .medium))
    }
    .foregroundStyle(CMColor.ink.opacity(0.75))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(CMColor.porcelain.opacity(0.75), in: Capsule())
    .overlay(Capsule().stroke(CMColor.hairline, lineWidth: 0.5))
  }
}
