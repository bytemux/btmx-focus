import BtmxFocusCore
import Foundation
import Testing

struct PreferencesTests {
    @Test func defaultsMatchSpec() {
        let preferences = Preferences()
        #expect(preferences.focusMinutes == 30)
        #expect(preferences.shortRestMinutes == 5)
        #expect(preferences.longRestMinutes == 15)
        #expect(preferences.longRestEvery == 4)
        #expect(preferences.dailyTarget == 10)
        #expect(preferences.showTimerInMenuBar == true)
        #expect(preferences.skipBreakIfIdle == true)
        #expect(preferences.autoStart == false)
        #expect(preferences.completionNotifications == true)
        #expect(preferences.soundOnShortcut == true)
        #expect(preferences.focusEndSound == "Glass")
        #expect(preferences.breakEndSound == "Hero")
        #expect(preferences.volume == 1.0)
    }

    @Test func focusAndBreakEndWithDifferentSoundsByDefault() {
        let preferences = Preferences()
        #expect(preferences.endSound(after: .focus) == "Glass")
        #expect(preferences.endSound(after: .rest) == "Hero")
    }

    @Test func soundNoneMeansNoEndSound() {
        var preferences = Preferences()
        preferences.focusEndSound = ""
        preferences.breakEndSound = "Ping"
        #expect(preferences.endSound(after: .focus) == nil)
        #expect(preferences.endSound(after: .rest) == "Ping")
    }

    @Test func soundPickerListsTheBuiltInSounds() {
        #expect(SystemSound.names == [
            "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
            "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
        ])
    }

    @Test func emptyDefaultsLoadTheDefaults() {
        #expect(Preferences(defaults: freshDefaults()) == Preferences())
    }

    @Test func savedSettingsSurviveReload() {
        let defaults = freshDefaults()
        var preferences = Preferences()
        preferences.focusMinutes = 50
        preferences.shortRestMinutes = 10
        preferences.longRestMinutes = 20
        preferences.longRestEvery = 2
        preferences.dailyTarget = 6
        preferences.showTimerInMenuBar = false
        preferences.skipBreakIfIdle = false
        preferences.autoStart = true
        preferences.completionNotifications = false
        preferences.soundOnShortcut = false
        preferences.focusEndSound = ""
        preferences.breakEndSound = "Ping"
        preferences.volume = 0.25
        preferences.save(to: defaults, changedFrom: Preferences())

        #expect(Preferences(defaults: defaults) == preferences)
    }

    /// Settings the user never touched follow future changes to their default.
    @Test func savingWritesOnlyTheChangedSettings() {
        let defaults = freshDefaults()
        var preferences = Preferences()
        preferences.showTimerInMenuBar = false
        preferences.save(to: defaults, changedFrom: Preferences())
        #expect(defaults.object(forKey: "showTimerInMenuBar") as? Bool == false)
        #expect(defaults.object(forKey: "focusMinutes") == nil)
    }

    @Test func valuesOfTheWrongTypeFallBackToTheirDefault() {
        let defaults = freshDefaults()
        defaults.set("loud", forKey: "volume")
        #expect(Preferences(defaults: defaults).volume == 1.0)
    }

    @Test func describesOnlyTheChangedSettings() {
        var changed = Preferences()
        changed.showTimerInMenuBar = false
        changed.focusMinutes = 45
        #expect(changed.changes(from: Preferences()) == ["focusMinutes 30 → 45", "showTimerInMenuBar true → false"])
        #expect(changed.changes(from: changed).isEmpty)
    }
}

/// An empty, per-test defaults domain.
private func freshDefaults() -> UserDefaults {
    let suite = "PreferencesTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
