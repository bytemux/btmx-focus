import AppKit

@main
@MainActor
enum BtmxFocusApp {
    static func main() {
        CrashLog.start()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Info.plist sets LSUIElement for the bundle; this covers `swift run`.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_: Notification) {
        let model = TimerModel(signaler: PhaseSignaler())
        statusItemController = StatusItemController(model: model)
    }

    func applicationWillTerminate(_: Notification) {
        CrashLog.markCleanExit()
    }
}
