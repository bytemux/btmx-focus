import BtmxFocusDriver
import BtmxFocusUIContract
import Foundation
import Testing

extension E2E {
    /// The critical path only, in as few launches as possible: each launch
    /// costs seconds. Details (every button, edge cases) belong in the unit
    /// and snapshot tests.
    struct CriticalPath {
        /// Status item → popover → Play / Pause / Space / Reset → phase end →
        /// Skip → Esc, on a 5 s focus and 2 s rest.
        @Test func timer() throws {
            try E2E.withApp("timer", E2E.shortSchedule) { app in
                try app.openPopover()
                try app.expectPopover(phase: "Focus", clock: "00:05", playPause: "Play")
                try app.waitUntil("the app has the keyboard") { app.isFrontmost }
                try app.screenshot("ready")

                try app.click(AccessibilityID.Popover.playPause)
                try app.waitUntil("running") { app.playPauseLabel == "Pause" }
                try app.waitUntil("time in the menu bar") { app.statusItemText.hasPrefix("00:0") }
                try app.waitUntil("red icon") { try app.statusItemTint("running-icon").red > 0 }
                try app.screenshot("running")

                try app.key("space")
                try app.waitUntil("paused by Space") { app.playPauseLabel == "Play" }
                try app.waitUntil("gray icon") { try app.statusItemTint("paused-icon").red == 0 }

                try app.click(AccessibilityID.Popover.reset)
                try app.expectPopover(phase: "Focus", clock: "00:05", playPause: "Play")

                try app.key("space")
                try app.waitUntil("rest loaded at phase end", timeout: 8) {
                    app.phase == "Rest" && app.clock == "00:02" && app.playPauseLabel == "Play"
                }
                try app.waitForBreadcrumb(containing: "signal: Glass sound")
                try app.screenshot("after-phase-end")

                try app.click(AccessibilityID.Popover.skip)
                try app.expectPopover(phase: "Focus", clock: "00:05", playPause: "Play")

                try app.key("escape")
                try app.waitUntilPopoverClosed()
                try app.waitUntil("the previous app has the keyboard again") { !app.isFrontmost }
            }
        }

        /// ⋯ → Settings…, "Show timer in menu bar" off → icon only while
        /// running; ⋯ → Quit; still off after relaunch.
        @Test func settingsAndQuit() throws {
            let toggle = AccessibilityID.Settings.showTimerInMenuBar
            try E2E.withApp("settings") { app in
                try app.openSettings()
                try app.screenshot("settings")
                try app.click(toggle)
                try app.waitUntil("toggle off") { try (app.element(toggle).value as? Int) == 0 }

                try app.openPopover()
                try app.click(AccessibilityID.Popover.playPause)
                try app.waitUntil("running, a second in") {
                    try E2E.clockText(fromLabel: app.statusItem().label ?? "") == "29:59"
                }
                #expect(app.statusItemText.isEmpty, "icon only while running")
                #expect(try app.statusItemTint("hidden-timer-icon").red > 0, "the icon is still red")
                try app.screenshot("running-icon-only")

                try app.click(AccessibilityID.Popover.more)
                try app.click(AccessibilityID.MoreMenu.quit)
                try app.waitUntil("the app has quit", timeout: 3) { !app.isRunning }
            }
            try E2E.withApp("settings-relaunch", resetSettings: false) { app in
                try app.openSettings()
                try app.waitUntil("still off after relaunch") { try (app.element(toggle).value as? Int) == 0 }
            }
        }
    }
}
