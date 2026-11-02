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
        let model = TimerModel(
            engine: TimerEngine(schedule: e2e?.schedule ?? .standard),
            signaler: PhaseSignaler(notificationsEnabled: e2e?.notificationsEnabled ?? true)
        )
        let settings = SettingsStore()
        statusItemController = StatusItemController(
            model: model, settings: settings, settingsWindow: SettingsWindowController(settings: settings)
        )
        if let e2e {
            CrashLog.record("e2e build: \(e2e)")
            observeSimulatedSleep()
        }
    }

    func applicationWillTerminate(_: Notification) {
        CrashLog.markCleanExit()
    }

    /// The E2E suite can't put the Mac to sleep; it asks for the same
    /// notification the system would post.
    private func observeSimulatedSleep() {
        DistributedNotificationCenter.default().addObserver(
            forName: .init(E2EContract.simulateSleepNotification), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                CrashLog.record("e2e: simulated sleep")
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
            }
        }
    }
}
