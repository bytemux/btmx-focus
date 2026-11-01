import BtmxFocusCore
import Foundation
import Observation

/// The live settings. Every change is saved to `UserDefaults` at once and
/// leaves a breadcrumb; observers (e.g. the status item) pick it up immediately.
@MainActor
@Observable
final class SettingsStore {
    var preferences: Preferences {
        didSet {
            let changes = preferences.changes(from: oldValue)
            guard !changes.isEmpty else { return }
            preferences.save(to: defaults, changedFrom: oldValue)
            CrashLog.record("settings: \(changes.joined(separator: ", "))")
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = Preferences(defaults: defaults)
    }
}
