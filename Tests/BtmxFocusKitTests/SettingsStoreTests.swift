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

    @Test func pickingAnEndSoundSavesItAndPlaysAPreviewAtTheSetVolume() {
        let (defaults, _) = freshDefaults()
        let player = RecordingSoundPlayer()
        let store = SettingsStore(defaults: defaults, soundPlayer: player)
        store.preferences.volume = 0.5

        store.pickEndSound("Ping", after: .focus)
        store.pickEndSound("Tink", after: .rest)

        #expect(player.played == [.init(name: "Ping", volume: 0.5), .init(name: "Tink", volume: 0.5)])
        let reloaded = SettingsStore(defaults: defaults).preferences
        #expect(reloaded.focusEndSound == "Ping")
        #expect(reloaded.breakEndSound == "Tink")
    }

    @Test func pickingNonePlaysNothing() {
        let player = RecordingSoundPlayer()
        let store = SettingsStore(defaults: freshDefaults().defaults, soundPlayer: player)

        store.pickEndSound("", after: .focus)

        #expect(store.preferences.endSound(after: .focus) == nil)
        #expect(player.played.isEmpty)
    }

    /// The Focus status permission is asked for only when the user wants it.
    @Test func turningOnSilentDuringFocusAsksToReadTheFocusStatus() {
        let focus = FakeFocusStatus()
        let store = SettingsStore(defaults: freshDefaults().defaults, focusStatus: focus)
        store.preferences.volume = 0.5
        #expect(focus.accessRequests == 0)

        store.preferences.silentDuringFocus = true
        store.preferences.silentDuringFocus = false

        #expect(focus.accessRequests == 1)
    }

    /// Shown only in a build that can read the Focus status (ADR 0014).
    @Test func silentDuringFocusIsOfferedOnlyWhenTheFocusStatusCanBeRead() {
        let defaults = freshDefaults().defaults
        #expect(SettingsStore(defaults: defaults, focusStatus: FakeFocusStatus()).canSilenceDuringFocus == false)
        #expect(SettingsStore(defaults: defaults, focusStatus: FakeFocusStatus(isAvailable: true))
            .canSilenceDuringFocus == true)
    }

    @Test func endSoundStaysSilentWhileAFocusModeIsOn() {
        let focus = FakeFocusStatus()
        let store = SettingsStore(defaults: freshDefaults().defaults, focusStatus: focus)
        store.preferences.silentDuringFocus = true

        focus.isFocusActive = true
        #expect(store.endSoundToPlay(after: .focus) == nil)
        focus.isFocusActive = false
        #expect(store.endSoundToPlay(after: .focus) == "Glass")
    }

    @Test func releasingTheVolumeSliderPreviewsAnEndSoundAtTheNewVolume() {
        let player = RecordingSoundPlayer()
        let store = SettingsStore(defaults: freshDefaults().defaults, soundPlayer: player)
        store.preferences.volume = 0.25
        store.volumeSliderReleased()

        store.preferences.focusEndSound = ""
        store.volumeSliderReleased()

        store.preferences.breakEndSound = ""
        store.volumeSliderReleased()

        #expect(player.played == [.init(name: "Glass", volume: 0.25), .init(name: "Hero", volume: 0.25)])
    }
}
