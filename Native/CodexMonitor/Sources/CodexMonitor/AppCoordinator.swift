import AppKit
import Observation
import SwiftUI

enum AppModalRoute: String, Identifiable {
  case newTask
  case settings

  var id: String { rawValue }
}

@MainActor
@Observable
final class AppCoordinator {
  var modalRoute: AppModalRoute?

  @ObservationIgnored private weak var mainWindow: NSWindow?
  @ObservationIgnored private var openMainWindow: (() -> Void)?

  func installMainWindowOpener(_ action: @escaping () -> Void) {
    openMainWindow = action
  }

  func registerMainWindow(_ window: NSWindow) {
    mainWindow = window
    window.identifier = NSUserInterfaceItemIdentifier("manager-workspace")
  }

  func showMainWindow() {
    NSApplication.shared.unhide(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)

    if bringKnownWindowToFront() { return }
    openMainWindow?()

    // SwiftUI creates a closed Window scene on the next run-loop turn.
    Task { @MainActor [weak self] in
      await Task.yield()
      _ = self?.bringKnownWindowToFront()
    }
  }

  func present(_ route: AppModalRoute) {
    modalRoute = route
    showMainWindow()
  }

  func dismissModal() {
    modalRoute = nil
  }

  @discardableResult
  private func bringKnownWindowToFront() -> Bool {
    guard
      let window = mainWindow
        ?? NSApplication.shared.windows.first(where: {
          $0.identifier?.rawValue == "manager-workspace"
        })
    else { return false }

    mainWindow = window
    if window.isMiniaturized { window.deminiaturize(nil) }
    window.makeKeyAndOrderFront(nil)
    return true
  }
}

struct MainWindowBridge: View {
  @Environment(\.openWindow) private var openWindow
  let coordinator: AppCoordinator
  let configureDelegate: () -> Void

  var body: some View {
    MainWindowReader(coordinator: coordinator)
      .frame(width: 0, height: 0)
      .accessibilityHidden(true)
      .onAppear {
        coordinator.installMainWindowOpener { openWindow(id: "main") }
        configureDelegate()
      }
  }
}

private struct MainWindowReader: NSViewRepresentable {
  let coordinator: AppCoordinator

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    registerWindow(for: view)
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    registerWindow(for: nsView)
  }

  private func registerWindow(for view: NSView) {
    DispatchQueue.main.async { [weak view] in
      guard let window = view?.window else { return }
      coordinator.registerMainWindow(window)
    }
  }
}
