import AppKit
import BtmxFocusCore
import BtmxFocusKit
import BtmxFocusUIContract

@main
@MainActor
enum BtmxFocusApp {
    static func main() {
        let e2e = E2EOptions.current
        if let e2e {
            prepareDefaults(for: e2e)
        }
        CrashLog.start()
        let app = NSApplication.shared
        let delegate = AppDelegate(e2e: e2e)
        app.delegate = delegate
        // Info.plist sets LSUIElement for the bundle; this covers `swift run`.
        app.setActivationPolicy(.accessory)
        app.mainMenu = mainMenu()
        app.run()
    }

    /// Never shown (the app has no menu bar of its own), but key equivalents
    /// go through it: without it ⌘W doesn't close the Settings window.
    private static func mainMenu() -> NSMenu {
        let windowMenu = NSMenu(title: String(localized: "Window"))
        windowMenu.addItem(
            withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"
        )
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        let menu = NSMenu()
        menu.addItem(windowItem)
        return menu
    }

    /// Before anything reads `UserDefaults`, so a wipe is seen everywhere.
    private static func prepareDefaults(for e2e: E2EOptions) {
        let defaults = UserDefaults.standard
        if e2e.resetSettings {
            defaults.removePersistentDomain(forName: E2EContract.bundleIdentifier)
        }
        if e2e.debugLogging {
            defaults.set(true, forKey: CrashLog.debugLoggingKey)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let e2e: E2EOptions?
    private var statusItemController: StatusItemController?

    init(e2e: E2EOptions?) {
        self.e2e = e2e
    }

    func applicationDidFinishLaunching(_: Notification) {
        let settings = SettingsStore()
        let model = TimerModel(
            engine: TimerEngine(schedule: schedule(from: settings)),
            signaler: PhaseSignaler(notificationsEnabled: e2e?.notificationsEnabled ?? true)
        )
        pushSchedule(from: settings, to: model)
        statusItemController = StatusItemController(
            model: model, settings: settings, settingsWindow: SettingsWindowController(settings: settings)
        )
        if let e2e {
            CrashLog.record("e2e build: \(e2e)")
        }
    }

    private func schedule(from settings: SettingsStore) -> Schedule {
        e2e?.schedule(from: settings.preferences) ?? settings.preferences.schedule
    }

    /// Hands every change of the interval settings to the timer, and re-arms
    /// observation for the next one. Only the settings are tracked, not the
    /// model, so timer ticks don't wake this.
    private func pushSchedule(from settings: SettingsStore, to model: TimerModel) {
        let newSchedule = withObservationTracking {
            self.schedule(from: settings)
        } onChange: { [weak self, weak settings, weak model] in
            Task { @MainActor in
                guard let self, let settings, let model else { return }
                self.pushSchedule(from: settings, to: model)
            }
        }
        model.setSchedule(newSchedule)
    }

    func applicationWillTerminate(_: Notification) {
        CrashLog.markCleanExit()
    }
}
