import BtmxFocusKit
import BtmxFocusTestSupport
import Foundation
import Testing

@MainActor
struct SettingsStoreTests {
    @Test func changingASettingSavesOnlyThatKey() {
        let (defaults, suite) = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.preferences.showTimerInMenuBar = false

        #expect(defaults.persistentDomain(forName: suite)?.keys.sorted() == ["showTimerInMenuBar"])
        #expect(SettingsStore(defaults: defaults).preferences.showTimerInMenuBar == false)
    }

    @Test func settingTheSameValueSavesNothing() {
        let (defaults, suite) = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.preferences.showTimerInMenuBar = true
        store.preferences = store.preferences

        #expect(defaults.persistentDomain(forName: suite)?.isEmpty ?? true)
    }
}
