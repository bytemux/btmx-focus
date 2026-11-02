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
