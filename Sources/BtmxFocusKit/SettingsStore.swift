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
            if preferences.silentDuringFocus, !oldValue.silentDuringFocus {
                focusStatus.requestAccess()
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let soundPlayer: SoundPlayer
    @ObservationIgnored private let focusStatus: FocusStatusSource

    public init(
        defaults: UserDefaults = .standard,
        soundPlayer: SoundPlayer = SystemSoundPlayer(),
        focusStatus: FocusStatusSource = SystemFocusStatus()
    ) {
        self.defaults = defaults
        self.soundPlayer = soundPlayer
        self.focusStatus = focusStatus
        preferences = Preferences(defaults: defaults)
    }

    /// The sound to play at the end of `phase` now: nil for "None", or while
    /// a Focus mode is on and Silent during Focus is set.
    public func endSoundToPlay(after phase: Phase) -> String? {
        let focusActive = preferences.silentDuringFocus ? focusStatus.isFocusActive : nil
        return preferences.endSound(after: phase, focusActive: focusActive)
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
