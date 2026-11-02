import BtmxFocusCore
import Foundation
import Observation

/// The live settings. Every change is saved to `UserDefaults` at once and
/// leaves a breadcrumb; observers (e.g. the status item) pick it up immediately.
@MainActor
@Observable
public final class SettingsStore {
    public var preferences: Preferences {
        didSet {
            let changes = preferences.changes(from: oldValue)
            guard !changes.isEmpty else { return }
            preferences.save(to: defaults, changedFrom: oldValue)
            CrashLog.record("settings: \(changes.joined(separator: ", "))")
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let soundPlayer: SoundPlayer

    public init(defaults: UserDefaults = .standard, soundPlayer: SoundPlayer = SystemSoundPlayer()) {
        self.defaults = defaults
        self.soundPlayer = soundPlayer
        preferences = Preferences(defaults: defaults)
    }

    /// Sets the sound for the end of `phase` ("" for None) and plays it as a preview.
    public func pickEndSound(_ name: String, after phase: Phase) {
        switch phase {
        case .focus: preferences.focusEndSound = name
        case .rest: preferences.breakEndSound = name
        }
        previewEndSound(after: phase)
    }

    /// Previews the new volume with the Focus-end sound, or the break-end one
    /// if that is None.
    public func volumeSliderReleased() {
        previewEndSound(after: preferences.endSound(after: .focus) == nil ? .rest : .focus)
    }

    private func previewEndSound(after phase: Phase) {
        guard let sound = preferences.endSound(after: phase) else { return }
        soundPlayer.play(sound, volume: preferences.volume)
    }
}
