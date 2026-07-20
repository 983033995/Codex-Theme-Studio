import AppKit
import SwiftUI

private let suppressWindowAfterRestartKey = "suppressWindowAfterSystemRestart"

@MainActor
final class PreviewAppDelegate: NSObject, NSApplicationDelegate {
  private var managementWindow: NSWindow?
  private var powerOffObserver: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ManagerInstanceService().becomePrimary() else { return }
    AppModel.shared.retireLegacyManagerIfNeeded()
    AppModel.shared.ensureLoginItemDefault()
    powerOffObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willPowerOffNotification,
      object: nil,
      queue: .main
    ) { _ in
      UserDefaults.standard.set(true, forKey: suppressWindowAfterRestartKey)
    }

    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--preview") {
      DispatchQueue.main.async { [weak self] in self?.showManagementWindow() }
      return
    }
    let resumedAfterRestart = UserDefaults.standard.bool(
      forKey: suppressWindowAfterRestartKey
    )
    UserDefaults.standard.removeObject(forKey: suppressWindowAfterRestartKey)
    guard !arguments.contains("--menubar-only"), !resumedAfterRestart else { return }
    DispatchQueue.main.async { [weak self] in self?.showManagementWindow() }
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let powerOffObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(powerOffObserver)
    }
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag { showManagementWindow() }
    return true
  }

  private func showManagementWindow() {
    if let managementWindow {
      NSApplication.shared.unhide(nil)
      managementWindow.makeKeyAndOrderFront(nil)
      managementWindow.orderFrontRegardless()
      NSApplication.shared.activate(ignoringOtherApps: true)
      return
    }

    let panel = ThemeStudioPanel()
      .environmentObject(AppModel.shared)
      .frame(width: 470, height: 720)
      .preferredColorScheme(.dark)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 470, height: 720),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Codex Theme Studio"
    window.contentView = NSHostingView(rootView: panel)
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    window.center()
    NSApplication.shared.unhide(nil)
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
    managementWindow = window
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}

@main
struct CodexThemeStudioApp: App {
  @NSApplicationDelegateAdaptor(PreviewAppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel.shared

  var body: some Scene {
    MenuBarExtra {
      ThemeStudioPanel()
        .environmentObject(model)
        .frame(width: 470, height: 720)
        .preferredColorScheme(.dark)
    } label: {
      Label("Theme Studio", systemImage: model.menuBarSymbol)
    }
    .menuBarExtraStyle(.window)
  }
}
