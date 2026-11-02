import BtmxFocusDriver
import BtmxFocusUIContract
import Foundation
import Testing

extension E2E {
    struct SettingsFlows {
        @Test func opensAndSwitchesTabs() throws {
            try E2E.withApp("settings-tabs") { app in
                try app.openSettings()
                try app.screenshot("settings-general")
                let toggle = AccessibilityID.Settings.showTimerInMenuBar
                for (tab, showsToggle) in [("Intervals", false), ("Notifications & Sounds", false), ("General", true)] {
                    try app.click(app.settingsTab(tab))
                    try app.waitUntil("\(tab) tab is selected") {
                        try (app.settingsTab(tab).value as? Int) == 1 && app.isShown(toggle) == showsToggle
                    }
                    try app.screenshot("settings-\(tab)")
                }
            }
        }

        @Test func hidingTheTimerKeepsTheIconAndSurvivesRelaunch() throws {
            let toggle = AccessibilityID.Settings.showTimerInMenuBar
            try E2E.withApp("hide-timer") { app in
                try app.openSettings()
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
            }
            try E2E.withApp("hide-timer-relaunch", resetSettings: false) { app in
                try app.openSettings()
                try app.waitUntil("still off after relaunch") { try (app.element(toggle).value as? Int) == 0 }
            }
        }

        @Test func closeAndReopenReusesTheWindow() throws {
            try E2E.withApp("settings-reuse") { app in
                try app.openSettings()
                let first = try app.wait(for: "Settings window id") { app.settingsWindowID() }
                try app.key("cmd+w")
                try app.waitUntil("Settings closed") { app.settingsWindowID() == nil }
                try app.openSettings()
                let second = try app.wait(for: "Settings window id") { app.settingsWindowID() }
                #expect(first == second, "the same window comes back")
            }
        }
    }
}
