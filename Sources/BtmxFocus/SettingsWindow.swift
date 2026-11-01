import AppKit
import SwiftUI

/// The one Settings window: AppKit `NSWindow` hosting SwiftUI (ADR 0002,
/// ADR 0008). Created on first open, then reused; its position is autosaved.
@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private var window: NSWindow?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Brings the window to the front with focus. The app has no Dock icon,
    /// so it must activate itself or the window opens behind other apps.
    func show() {
        CrashLog.record("settings open")
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView(settings: settings))
        controller.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: controller)
        window.title = String(localized: "btmx-focus Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        let autosaveName = "Settings"
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(autosaveName)
        return window
    }
}

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                Form {
                    Toggle("Show timer in menu bar", isOn: $settings.preferences.showTimerInMenuBar)
                }
            }
            Tab("Intervals", systemImage: "timer") {
                Form {}
            }
            Tab("Notifications & Sounds", systemImage: "bell.badge") {
                Form {}
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 300)
    }
}
