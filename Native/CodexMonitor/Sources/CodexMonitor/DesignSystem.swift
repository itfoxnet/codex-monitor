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
  static let focusRing = Color.accentColor
}

enum CMMotion {
  static let hover: Double = 0.09
  static let press: Double = 0.06
  static let settle: Double = 0.12
}

enum CMFont {
  static let largeTitle = Font.largeTitle.weight(.bold)
  static let title = Font.title2.weight(.bold)
  static let headline = Font.headline
  static let bodyText = Font.body
  static let callout = Font.callout
  static let caption = Font.caption
  static let caption2 = Font.caption2

  static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
    semanticFont(for: size, weight: weight, design: .rounded)
  }

  static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
    semanticFont(for: size, weight: weight, design: .default)
  }

  static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
    semanticFont(for: size, weight: weight, design: .monospaced).monospacedDigit()
  }

  private static func semanticFont(
    for size: CGFloat,
    weight: Font.Weight,
    design: Font.Design
  ) -> Font {
    let style: Font.TextStyle =
      switch size {
      case 24...: .title
      case 18..<24: .title2
      case 15..<18: .headline
      case 13..<15: .body
      case 11..<13: .callout
      case 10..<11: .caption
      default: .caption2
      }
    return .system(style, design: design, weight: weight)
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

// MARK: - Interaction language

/// The large selectable surface of a task card. Selection is persistent; hover, press,
/// focus and disabled states are transient and never change the view's layout.
struct CMTaskCardButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  let selected: Bool

  func makeBody(configuration: Configuration) -> some View {
    CMTaskCardButtonStyleBody(
      configuration: configuration,
      selected: selected,
      isEnabled: isEnabled,
      reduceMotion: reduceMotion,
      increasedContrast: contrast == .increased
    )
  }
}

/// Plain custom controls keep AppKit's keyboard focus ring visible. Use this for
/// buttons whose visual surface is drawn by their container.
struct CMKeyboardFocusableModifier: ViewModifier {
  @FocusState private var focused: Bool

  func body(content: Content) -> some View {
    content
      .focusable()
      .focused($focused)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(CMColor.focusRing, lineWidth: focused ? 2 : 0)
          .padding(1)
      )
  }
}

extension View {
  func cmKeyboardFocusable() -> some View {
    modifier(CMKeyboardFocusableModifier())
  }
}

private struct CMTaskCardButtonStyleBody: View {
  let configuration: ButtonStyleConfiguration
  let selected: Bool
  let isEnabled: Bool
  let reduceMotion: Bool
  let increasedContrast: Bool

  @State private var isHovered = false

  var body: some View {
    configuration.label
      .foregroundStyle(CMColor.ink)
      .background(backgroundColor)
      .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
      .opacity(isEnabled ? 1 : 0.46)
      .contentShape(RoundedRectangle(cornerRadius: 8))
      .onHover { isHovered = isEnabled && $0 }
      .animation(animation, value: isHovered)
      .animation(animation, value: configuration.isPressed)
      .animation(settleAnimation, value: selected)
  }

  private var backgroundColor: Color {
    if configuration.isPressed { return CMColor.ink.opacity(increasedContrast ? 0.11 : 0.07) }
    if isHovered { return CMColor.ink.opacity(increasedContrast ? 0.075 : 0.035) }
    if selected { return CMColor.ink.opacity(increasedContrast ? 0.055 : 0.025) }
    return .clear
  }

  private var animation: Animation? {
    reduceMotion
      ? nil
      : .easeOut(duration: configuration.isPressed ? CMMotion.press : CMMotion.hover)
  }

  private var settleAnimation: Animation? {
    reduceMotion ? nil : .easeOut(duration: CMMotion.settle)
  }
}

/// A full-width navigation row. Its persistent selected treatment is intentionally
/// stronger than hover so moving the pointer never obscures the current project.
struct CMRowButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  let selected: Bool

  func makeBody(configuration: Configuration) -> some View {
    CMRowButtonStyleBody(
      configuration: configuration,
      selected: selected,
      isEnabled: isEnabled,
      reduceMotion: reduceMotion,
      increasedContrast: contrast == .increased
    )
  }
}

private struct CMRowButtonStyleBody: View {
  let configuration: ButtonStyleConfiguration
  let selected: Bool
  let isEnabled: Bool
  let reduceMotion: Bool
  let increasedContrast: Bool

  @State private var isHovered = false

  var body: some View {
    configuration.label
      .background(backgroundColor, in: RoundedRectangle(cornerRadius: 7))
      .overlay(alignment: .leading) {
        if selected {
          RoundedRectangle(cornerRadius: 2)
            .fill(CMColor.ink)
            .frame(width: increasedContrast ? 4 : 3)
            .padding(.vertical, 3)
        }
      }
      .overlay(
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(borderColor, lineWidth: borderWidth)
      )
      .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
      .opacity(isEnabled ? 1 : 0.46)
      .contentShape(RoundedRectangle(cornerRadius: 7))
      .onHover { isHovered = isEnabled && $0 }
      .animation(animation, value: isHovered)
      .animation(animation, value: configuration.isPressed)
      .animation(settleAnimation, value: selected)
  }

  private var backgroundColor: Color {
    if configuration.isPressed { return CMColor.ink.opacity(increasedContrast ? 0.13 : 0.085) }
    if selected { return CMColor.porcelain }
    if isHovered { return CMColor.ink.opacity(increasedContrast ? 0.085 : 0.045) }
    return .clear
  }

  private var borderColor: Color {
    if selected { return CMColor.ink.opacity(increasedContrast ? 0.7 : 0.22) }
    if isHovered || configuration.isPressed {
      return CMColor.ink.opacity(increasedContrast ? 0.65 : 0.2)
    }
    return .clear
  }

  private var borderWidth: CGFloat {
    increasedContrast ? 1.5 : 0.75
  }

  private var animation: Animation? {
    reduceMotion
      ? nil
      : .easeOut(duration: configuration.isPressed ? CMMotion.press : CMMotion.hover)
  }

  private var settleAnimation: Animation? {
    reduceMotion ? nil : .easeOut(duration: CMMotion.settle)
  }
}

/// Compact command rows used by the menu bar panel.
struct CMMenuRowButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  func makeBody(configuration: Configuration) -> some View {
    CMMenuRowButtonStyleBody(
      configuration: configuration,
      isEnabled: isEnabled,
      reduceMotion: reduceMotion,
      increasedContrast: contrast == .increased
    )
  }
}

private struct CMMenuRowButtonStyleBody: View {
  let configuration: ButtonStyleConfiguration
  let isEnabled: Bool
  let reduceMotion: Bool
  let increasedContrast: Bool

  @State private var isHovered = false

  var body: some View {
    configuration.label
      .background(backgroundColor, in: RoundedRectangle(cornerRadius: 7))
      .overlay(
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(borderColor, lineWidth: increasedContrast ? 1.5 : 0.75)
      )
      .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
      .opacity(isEnabled ? 1 : 0.46)
      .contentShape(RoundedRectangle(cornerRadius: 7))
      .onHover { isHovered = isEnabled && $0 }
      .animation(animation, value: isHovered)
      .animation(animation, value: configuration.isPressed)
  }

  private var backgroundColor: Color {
    if configuration.isPressed { return CMColor.ink.opacity(increasedContrast ? 0.14 : 0.09) }
    if isHovered { return CMColor.ink.opacity(increasedContrast ? 0.085 : 0.045) }
    return .clear
  }

  private var borderColor: Color {
    if isHovered || configuration.isPressed {
      return CMColor.ink.opacity(increasedContrast ? 0.65 : 0.18)
    }
    return .clear
  }

  private var animation: Animation? {
    reduceMotion
      ? nil
      : .easeOut(duration: configuration.isPressed ? CMMotion.press : CMMotion.hover)
  }
}

/// Icon-only controls use a fixed 32-point hit target and always expose a visible
/// hover/press surface instead of relying on a glyph color change alone.
struct CMIconButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  var tint: Color = CMColor.ink
  var destructive = false

  func makeBody(configuration: Configuration) -> some View {
    CMIconButtonStyleBody(
      configuration: configuration,
      isEnabled: isEnabled,
      reduceMotion: reduceMotion,
      increasedContrast: contrast == .increased,
      tint: destructive ? CMColor.raiseRed : tint
    )
  }
}

private struct CMIconButtonStyleBody: View {
  let configuration: ButtonStyleConfiguration
  let isEnabled: Bool
  let reduceMotion: Bool
  let increasedContrast: Bool
  let tint: Color

  @State private var isHovered = false

  var body: some View {
    configuration.label
      .foregroundStyle(tint.opacity(isEnabled ? 1 : 0.46))
      .frame(minWidth: 32, minHeight: 32)
      .background(backgroundColor, in: RoundedRectangle(cornerRadius: 6))
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(borderColor, lineWidth: increasedContrast ? 1.5 : 0.75)
      )
      .shadow(
        color: CMColor.ink.opacity(isHovered && isEnabled ? 0.09 : 0),
        radius: 4,
        y: 2
      )
      .offset(y: configuration.isPressed && !reduceMotion ? 1 : 0)
      .contentShape(RoundedRectangle(cornerRadius: 6))
      .onHover { isHovered = isEnabled && $0 }
      .animation(animation, value: isHovered)
      .animation(animation, value: configuration.isPressed)
  }

  private var backgroundColor: Color {
    if configuration.isPressed { return tint.opacity(increasedContrast ? 0.2 : 0.14) }
    if isHovered { return tint.opacity(increasedContrast ? 0.14 : 0.08) }
    return .clear
  }

  private var borderColor: Color {
    if isHovered || configuration.isPressed { return tint.opacity(increasedContrast ? 0.8 : 0.28) }
    return .clear
  }

  private var animation: Animation? {
    reduceMotion
      ? nil
      : .easeOut(duration: configuration.isPressed ? CMMotion.press : CMMotion.hover)
  }
}
