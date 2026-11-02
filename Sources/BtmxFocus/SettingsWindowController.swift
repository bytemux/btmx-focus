import AppKit
import BtmxFocusKit
import BtmxFocusUIContract
import SwiftUI

/// The one Settings window: AppKit `NSWindow` hosting SwiftUI (ADR 0002,
/// ADR 0008). Created on first open, then reused; its position is autosaved.
@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private let launchAtLogin = LaunchAtLogin()
    private var window: NSWindow?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    /// Brings the window to the front with focus. The app has no Dock icon,
    /// so it must activate itself or the window opens behind other apps.
    func show() {
        CrashLog.record("settings open")
        let window = window ?? makeWindow()
        self.window = window
        launchAtLogin.refresh()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView(settings: settings, launchAtLogin: launchAtLogin))
        controller.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: controller)
        window.title = String(localized: "btmx-focus Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setAccessibilityIdentifier(AccessibilityID.Settings.window)
        let autosaveName = "Settings"
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(autosaveName)
        return window
    }
}
