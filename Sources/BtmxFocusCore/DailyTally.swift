import Foundation

/// How many Focus intervals the user completed today, for "Today n/target".
/// The count belongs to one local day and reads as 0 from the next midnight.
public struct DailyTally: Sendable, Equatable {
    /// Any instant within the day `count` belongs to; `nil` before the first one.
    private var day: Date?
    private var count = 0

    public init() {}

    public func count(on date: Date, calendar: Calendar = .current) -> Int {
        guard let day, calendar.isDate(day, inSameDayAs: date) else { return 0 }
        return count
    }

    public mutating func recordFocusInterval(at date: Date, calendar: Calendar = .current) {
        count = count(on: date, calendar: calendar) + 1
        day = date
    }
}

/// Two `UserDefaults` keys, `dailyTallyDay` and `dailyTallyCount`, so the
/// count survives quit and relaunch.
public extension DailyTally {
    init(defaults: UserDefaults) {
        day = defaults.object(forKey: "dailyTallyDay") as? Date
        count = defaults.object(forKey: "dailyTallyCount") as? Int ?? 0
    }

    func save(to defaults: UserDefaults) {
        defaults.set(day, forKey: "dailyTallyDay")
        defaults.set(count, forKey: "dailyTallyCount")
    }
}
