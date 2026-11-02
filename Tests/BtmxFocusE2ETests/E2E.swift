import BtmxFocusDriver
import BtmxFocusUIContract
import Foundation
import Testing

/// End-to-end tests of the bundled E2E build (ADR 0010): they launch the real
/// app and click through it like a user. Skipped unless `E2E=1`; run them with
/// `scripts/e2e.sh`, which builds the app first. They take over the mouse
/// and keyboard while they run.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["E2E"] == "1", "set E2E=1 (scripts/e2e.sh)"), .serialized)
enum E2E {
    /// One folder of screenshots for the whole run.
    static let artifacts = Artifacts()

    /// Launches a fresh app with its settings wiped, runs `body`, and quits
    /// it. On failure saves the artefacts first. Fails if the run left a
    /// modifier or mouse button held, after releasing it.
    static func withApp(
        _ name: String, _ arguments: [String] = [], resetSettings: Bool = true, _ body: (FocusApp) throws -> Void
    ) throws {
        let app = FocusApp(artifacts: artifacts)
        let reset = resetSettings ? [E2EContract.Argument.resetSettings] : []
        do {
            try app.launch(FocusApp.quietArguments + reset + arguments)
            try body(app)
            if let leaked = app.releaseLeakedInput() {
                throw DriverError("The test left \(leaked) held down (released now)")
            }
        } catch {
            app.saveFailureArtifacts(name, error: error)
            _ = app.releaseLeakedInput()
            try? app.quit()
            throw error
        }
        try app.quit()
    }

    /// "Focus, ready, 30 minutes remaining" → "30:00"; "" if there's no time in it.
    static func clockText(fromLabel label: String) -> String {
        let units = ["hour": 3600, "minute": 60, "second": 1]
        var seconds = 0
        var found = false
        for match in label.matches(of: /(\d+) (hour|minute|second)s?/) {
            seconds += (Int(match.1) ?? 0) * (units[String(match.2)] ?? 0)
            found = true
        }
        return found ? String(format: "%02d:%02d", seconds / 60, seconds % 60) : ""
    }

    /// Focus 5 s, rest 2 s.
    static let shortSchedule = [
        E2EContract.Argument.focusSeconds, "5", E2EContract.Argument.restSeconds, "2",
    ]
}

/// Reading what the user sees.
extension FocusApp {
    func openPopover() throws {
        try clickStatusItem()
        _ = try element(AccessibilityID.Popover.root)
    }

    func text(_ identifier: String) throws -> String {
        let element = try element(identifier)
        return (element.value as? String) ?? element.title ?? ""
    }

    var phase: String { (try? text(AccessibilityID.Popover.phase)) ?? "" }
    /// The popover's clock as shown, e.g. "29:59". Its AX value is the
    /// VoiceOver label ("Focus, running, 29 minutes, 59 seconds remaining"),
    /// so the time is read back from that.
    var clock: String { E2E.clockText(fromLabel: (try? text(AccessibilityID.Popover.clock)) ?? "") }
    var playPauseLabel: String { (try? element(AccessibilityID.Popover.playPause).label) ?? "" }

    /// What the status item shows next to its icon ("" for icon only).
    var statusItemText: String {
        let item = try? statusItem()
        return (item?.title ?? "").trimmingCharacters(in: .whitespaces)
    }

    func expectPopover(phase: String, clock: String, playPause: String) throws {
        try waitUntil("popover shows \(phase) \(clock) \(playPause)") {
            self.phase == phase && self.clock == clock && playPauseLabel == playPause
        }
    }

    /// Red/green pixel counts of the status item right now.
    func statusItemTint(_ name: String) throws -> (red: Int, green: Int) {
        try Pixels.tint(of: statusItemImage(name))
    }

    func waitUntilPopoverClosed(timeout: TimeInterval = FocusApp.defaultTimeout) throws {
        try waitUntil("the popover is closed", timeout: timeout) { !isShown(AccessibilityID.Popover.root) }
    }

    func openSettings() throws {
        try openPopover()
        try click(AccessibilityID.Popover.more)
        let mark = breadcrumbMark
        try click(AccessibilityID.MoreMenu.settings)
        _ = try element(AccessibilityID.Settings.window)
        // The popover fades out for ~0.5 s and leaves the AX tree before it
        // has really closed, and the app ignores a click on the item within
        // 0.3 s of a close (it takes it for the click that closed it).
        try waitForBreadcrumb(containing: "popover close", since: mark)
        Thread.sleep(forTimeInterval: 0.35)
    }
}
