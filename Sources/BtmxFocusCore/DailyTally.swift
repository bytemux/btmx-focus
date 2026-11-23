import Foundation

/// Today's progress, for the popover's daily dots: how many Focus intervals
/// the user completed and how much focused time they spent. Both belong to
/// one local day and read as zero from the next midnight.
public struct DailyTally: Sendable, Equatable {
    /// Any instant within the day the totals belong to; `nil` before the first one.
    private var day: Date?
    private var count = 0
    private var focusedSeconds: TimeInterval = 0

    public init() {}

    public func count(on date: Date, calendar: Calendar = .current) -> Int {
        isToday(date, calendar) ? count : 0
    }

    /// Focused time recorded for the day of `date`.
    public func focusedTime(on date: Date, calendar: Calendar = .current) -> Duration {
        .seconds(isToday(date, calendar) ? focusedSeconds : 0)
    }

    public mutating func recordFocusInterval(at date: Date, calendar: Calendar = .current) {
        roll(to: date, calendar)
        count += 1
    }

    /// Adds a stretch of Running Focus that ended at `end`. Only the part
    /// after the midnight before `end` counts: the rest belongs to a day
    /// nobody sees any more.
    public mutating func recordFocusedTime(from start: Date, to end: Date, calendar: Calendar = .current) {
        let from = max(start, calendar.startOfDay(for: end))
        guard end > from else { return }
        roll(to: end, calendar)
        focusedSeconds += end.timeIntervalSince(from)
    }

    /// Today starts over: no Focus intervals, no focused time.
    public mutating func resetDay(at date: Date) {
        day = date
        count = 0
        focusedSeconds = 0
    }

    private func isToday(_ date: Date, _ calendar: Calendar) -> Bool {
        guard let day else { return false }
        return calendar.isDate(day, inSameDayAs: date)
    }

    /// Starts the totals again when `date` is on a new day.
    private mutating func roll(to date: Date, _ calendar: Calendar) {
        if !isToday(date, calendar) {
            count = 0
            focusedSeconds = 0
        }
        day = date
    }
}

/// `UserDefaults` keys `dailyTallyDay`, `dailyTallyCount` and
/// `dailyTallyFocusedSeconds`, so the totals survive quit and relaunch.
public extension DailyTally {
    init(defaults: UserDefaults) {
        day = defaults.object(forKey: "dailyTallyDay") as? Date
        count = defaults.object(forKey: "dailyTallyCount") as? Int ?? 0
        focusedSeconds = defaults.object(forKey: "dailyTallyFocusedSeconds") as? TimeInterval ?? 0
    }

    func save(to defaults: UserDefaults) {
        defaults.set(day, forKey: "dailyTallyDay")
        defaults.set(count, forKey: "dailyTallyCount")
        defaults.set(focusedSeconds, forKey: "dailyTallyFocusedSeconds")
    }
}
