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
        #expect(preferences.silentDuringFocus == false)
        #expect(preferences.appearance == .auto)
    }

    @Test func focusAndBreakEndWithDifferentSoundsByDefault() {
        let preferences = Preferences()
        #expect(preferences.endSound(after: .focus) == "Glass")
        #expect(preferences.endSound(after: .rest) == "Hero")
        #expect(preferences.endSound(after: .longRest) == "Hero")
    }

    @Test func soundNoneMeansNoEndSound() {
        var preferences = Preferences()
        preferences.focusEndSound = ""
        preferences.breakEndSound = "Ping"
        #expect(preferences.endSound(after: .focus) == nil)
        #expect(preferences.endSound(after: .rest) == "Ping")
    }

    @Test func silentDuringFocusMutesTheEndSoundOnlyWhileAFocusIsOn() {
        var preferences = Preferences()
        preferences.silentDuringFocus = true
        #expect(preferences.endSound(after: .focus, focusActive: true) == nil)
        #expect(preferences.endSound(after: .rest, focusActive: true) == nil)
        #expect(preferences.endSound(after: .focus, focusActive: false) == "Glass")
    }

    /// The end of a phase must be noticed (ADR 0007): when the Focus status
    /// can't be read (no permission), the sound plays.
    @Test func unknownFocusStatusPlaysTheEndSound() {
        var preferences = Preferences()
        preferences.silentDuringFocus = true
        #expect(preferences.endSound(after: .rest, focusActive: nil) == "Hero")
    }

    @Test func endSoundIgnoresFocusWhileTheOptionIsOff() {
        #expect(Preferences().endSound(after: .focus, focusActive: true) == "Glass")
    }

    @Test func soundPickerListsTheBuiltInSounds() {
        #expect(SystemSound.names == [
            "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
            "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
        ])
    }

    @Test func intervalPresetsIncludeTheDefaults() {
        let preferences = Preferences()
        #expect(Preferences.focusMinuteOptions.contains(preferences.focusMinutes))
        #expect(Preferences.shortRestMinuteOptions.contains(preferences.shortRestMinutes))
        #expect(Preferences.longRestMinuteOptions.contains(preferences.longRestMinutes))
        #expect(Preferences.longRestEveryOptions.contains(preferences.longRestEvery))
        // The manual check: Focus 1 min, long break after 2.
        #expect(Preferences.focusMinuteOptions.contains(1))
        #expect(Preferences.longRestEveryOptions.contains(2))
    }

    @Test func scheduleFollowsTheIntervalSettings() {
        var preferences = Preferences()
        #expect(preferences.schedule == .standard)
        preferences.focusMinutes = 50
        preferences.shortRestMinutes = 10
        preferences.longRestMinutes = 20
        preferences.longRestEvery = 2
        #expect(preferences.schedule == Schedule(
            focus: .seconds(3000), rest: .seconds(600), longRest: .seconds(1200), longRestEvery: 2
        ))
    }

    @Test func phaseEndOptionsFollowTheGeneralSettings() {
        var preferences = Preferences()
        #expect(preferences.phaseEnd == PhaseEndOptions(autoStart: false, skipBreakIfIdle: true))
        preferences.autoStart = true
        preferences.skipBreakIfIdle = false
        #expect(preferences.phaseEnd == PhaseEndOptions(autoStart: true, skipBreakIfIdle: false))
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
        preferences.silentDuringFocus = true
        preferences.appearance = .dark
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

    @Test func appearanceIsSavedByName() {
        let defaults = freshDefaults()
        var preferences = Preferences()
        preferences.appearance = .light
        preferences.save(to: defaults, changedFrom: Preferences())
        #expect(defaults.string(forKey: "appearance") == "light")
        #expect(preferences.changes(from: Preferences()) == ["appearance auto → light"])
    }

    @Test func unknownAppearanceFallsBackToAuto() {
        let defaults = freshDefaults()
        defaults.set("sepia", forKey: "appearance")
        #expect(Preferences(defaults: defaults).appearance == .auto)
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
