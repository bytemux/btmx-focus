import BtmxFocusDriver
import BtmxFocusUIContract
import Foundation
import Testing

extension E2E {
    struct TimerFlows {
        @Test func statusItemOpensReadyPopover() throws {
            try E2E.withApp("ready-popover") { app in
                #expect(app.statusItemText.isEmpty, "Ready shows the icon only")
                try app.openPopover()
                try app.expectPopover(phase: "Focus", clock: "30:00", playPause: "Play")
                try app.waitUntil("the app has the keyboard") { app.isFrontmost }
                try app.screenshot("ready-focus")
            }
        }

        @Test func playPauseResume() throws {
            try E2E.withApp("play-pause") { app in
                try app.openPopover()
                try app.click(AccessibilityID.Popover.playPause)
                try app.waitUntil("running", timeout: 3) {
                    app.playPauseLabel == "Pause" && app.clock.hasPrefix("29:5")
                }
                try app.waitUntil("time in the menu bar") { app.statusItemText.hasPrefix("29:5") }
                try app.waitUntil("red icon") { try app.statusItemTint("running-icon").red > 0 }
                try app.screenshot("running-focus")

                try app.click(AccessibilityID.Popover.playPause)
                try app.waitUntil("paused") { app.playPauseLabel == "Play" }
                try app.waitUntil("gray icon") { try app.statusItemTint("paused-icon").red == 0 }
                let frozen = app.clock
                let frozenItem = app.statusItemText
                Thread.sleep(forTimeInterval: 1.5)
                #expect(app.clock == frozen, "paused clock doesn't move")
                #expect(app.statusItemText == frozenItem, "paused menu-bar time doesn't move")
                try app.screenshot("paused")

                try app.click(AccessibilityID.Popover.playPause)
                try app.waitUntil("resumed", timeout: 3) {
                    app.playPauseLabel == "Pause" && app.clock != frozen
                }
            }
        }

        @Test func skipThenReset() throws {
            try E2E.withApp("skip-reset") { app in
                try app.openPopover()
                try app.click(AccessibilityID.Popover.skip)
                try app.expectPopover(phase: "Rest", clock: "05:00", playPause: "Play")
                try app.screenshot("ready-rest")
                try app.click(AccessibilityID.Popover.reset)
                try app.expectPopover(phase: "Focus", clock: "30:00", playPause: "Play")
                try app.screenshot("after-reset")
            }
        }

        @Test func phaseEndWaitsForPlay() throws {
            try E2E.withApp("phase-end", E2E.shortSchedule) { app in
                try app.openPopover()
                try app.expectPopover(phase: "Focus", clock: "00:03", playPause: "Play")
                try app.click(AccessibilityID.Popover.playPause)
                try app.waitUntil("rest is loaded", timeout: 6) {
                    app.phase == "Rest" && app.clock == "00:02" && app.playPauseLabel == "Play"
                }
                try app.waitForBreadcrumb(containing: "phase end: Focus")
                try app.waitForBreadcrumb(containing: "signal: Glass sound")
                try app.screenshot("after-phase-end")
                Thread.sleep(forTimeInterval: 1.5)
                #expect(app.clock == "00:02", "the next phase waits for Play")
            }
        }

        @Test func simulatedSleepResets() throws {
            try E2E.withApp("sleep-reset") { app in
                try app.openPopover()
                try app.click(AccessibilityID.Popover.skip)
                try app.click(AccessibilityID.Popover.playPause)
                try app.waitUntil("rest running") { app.phase == "Rest" && app.playPauseLabel == "Pause" }
                DistributedNotificationCenter.default().postNotificationName(
                    .init(E2EContract.simulateSleepNotification), object: nil, deliverImmediately: true
                )
                try app.waitForBreadcrumb(containing: "system sleep, reset")
                try app.expectPopover(phase: "Focus", clock: "30:00", playPause: "Play")
                try app.screenshot("after-sleep")
            }
        }

        @Test func clickOutsideClosesPopover() throws {
            try E2E.withApp("click-outside") { app in
                try app.openPopover()
                try app.clickOutside()
                try app.waitUntilPopoverClosed()
                try app.screenshot("closed-by-click-outside")
            }
        }

        @Test func statusItemClickWhileOpenCloses() throws {
            try E2E.withApp("toggle-closes") { app in
                try app.openPopover()
                try app.clickStatusItem()
                try app.waitUntilPopoverClosed()
                // A negative check needs a wait: past the app's 0.3 s guard.
                Thread.sleep(forTimeInterval: 0.6)
                #expect(!app.isShown(AccessibilityID.Popover.root), "the same click doesn't reopen it")
                try app.screenshot("closed-by-item-click")
            }
        }

        @Test func spaceTogglesPlayPause() throws {
            try E2E.withApp("space") { app in
                try app.openPopover()
                try app.key("space")
                try app.waitUntil("running") { app.playPauseLabel == "Pause" }
                try app.screenshot("space-running")
                try app.key("space")
                try app.waitUntil("paused") { app.playPauseLabel == "Play" }
            }
        }

        @Test func escapeClosesPopoverAndHandsBackTheKeyboard() throws {
            try E2E.withApp("escape") { app in
                try app.openPopover()
                try app.waitUntil("the app has the keyboard") { app.isFrontmost }
                try app.key("escape")
                try app.waitUntilPopoverClosed()
                try app.waitUntil("the previous app has the keyboard again") { !app.isFrontmost }
                try app.screenshot("closed-by-escape")
            }
        }

        @Test func quitFromMoreMenu() throws {
            try E2E.withApp("quit") { app in
                try app.openPopover()
                try app.click(AccessibilityID.Popover.more)
                try app.screenshot("more-menu")
                try app.click(AccessibilityID.MoreMenu.quit)
                try app.waitUntil("the app has quit", timeout: 3) { !app.isRunning }
            }
        }
    }
}
