import Foundation

/// Every user setting with its default. Lengths are in minutes; an empty
/// sound name means no sound.
public struct Preferences: Sendable, Equatable {
    public var focusMinutes = 30
    public var shortRestMinutes = 5
    public var longRestMinutes = 15
    /// A long rest replaces the short one after this many completed Focus intervals.
    public var longRestEvery = 4
    /// Completed Focus intervals per day, shown as "Today n/target".
    public var dailyTarget = 10
    public var showTimerInMenuBar = true
    public var skipBreakIfIdle = true
    public var autoStart = false
    public var completionNotifications = true
    public var soundOnShortcut = true
    public var focusEndSound = "Glass"
    public var breakEndSound = "Hero"
    /// `NSSound.volume`, 0...1.
    public var volume = 1.0

    public init() {}
}

/// One `UserDefaults` key per setting, named after the property. Missing keys
/// and values of the wrong type read as the default.
public extension Preferences {
    init(defaults: UserDefaults) {
        func read<Value>(_ key: String, _ fallback: Value) -> Value {
            defaults.object(forKey: key) as? Value ?? fallback
        }
        let standard = Preferences()
        focusMinutes = read("focusMinutes", standard.focusMinutes)
        shortRestMinutes = read("shortRestMinutes", standard.shortRestMinutes)
        longRestMinutes = read("longRestMinutes", standard.longRestMinutes)
        longRestEvery = read("longRestEvery", standard.longRestEvery)
        dailyTarget = read("dailyTarget", standard.dailyTarget)
        showTimerInMenuBar = read("showTimerInMenuBar", standard.showTimerInMenuBar)
        skipBreakIfIdle = read("skipBreakIfIdle", standard.skipBreakIfIdle)
        autoStart = read("autoStart", standard.autoStart)
        completionNotifications = read("completionNotifications", standard.completionNotifications)
        soundOnShortcut = read("soundOnShortcut", standard.soundOnShortcut)
        focusEndSound = read("focusEndSound", standard.focusEndSound)
        breakEndSound = read("breakEndSound", standard.breakEndSound)
        volume = read("volume", standard.volume)
    }

    /// Writes only the settings that differ from `old`, so settings the user
    /// never touched keep following their default.
    func save(to defaults: UserDefaults, changedFrom old: Preferences) {
        for change in changedSettings(from: old) {
            defaults.set(change.new, forKey: change.key)
        }
    }

    /// e.g. `["showTimerInMenuBar true → false"]`, for the recent-actions log.
    func changes(from old: Preferences) -> [String] {
        changedSettings(from: old).map { "\($0.key) \($0.old) → \($0.new)" }
    }

    private struct Change {
        let key: String
        let old: Any
        let new: Any
    }

    private func changedSettings(from old: Preferences) -> [Change] {
        zip(old.settings, settings).compactMap { before, after in
            let (key, oldValue) = before
            let newValue = after.1
            return String(describing: oldValue) == String(describing: newValue)
                ? nil : Change(key: key, old: oldValue, new: newValue)
        }
    }

    /// Each setting as (property name, value), in declaration order.
    private var settings: [(String, Any)] {
        Mirror(reflecting: self).children.compactMap { child in child.label.map { ($0, child.value) } }
    }
}
