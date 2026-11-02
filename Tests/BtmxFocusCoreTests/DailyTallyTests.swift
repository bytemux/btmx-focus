import BtmxFocusCore
import Foundation
import Testing

/// Berlin, so "local day" differs from the UTC day.
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

/// 2026-11-02 at `hour`:`minute` local time.
private func november2(_ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: hour, minute: minute))!
}

struct DailyTallyTests {
    @Test func startsAtZero() {
        #expect(DailyTally().count(on: november2(9), calendar: calendar) == 0)
    }

    @Test func countsFocusIntervalsWithinADay() {
        var tally = DailyTally()
        tally.recordFocusInterval(at: november2(0, 30), calendar: calendar)
        tally.recordFocusInterval(at: november2(14), calendar: calendar)
        tally.recordFocusInterval(at: november2(23, 59), calendar: calendar)
        #expect(tally.count(on: november2(23, 59), calendar: calendar) == 3)
    }

    @Test func restartsOnTheNextLocalDay() {
        var tally = DailyTally()
        tally.recordFocusInterval(at: november2(22), calendar: calendar)
        tally.recordFocusInterval(at: november2(23, 30), calendar: calendar)
        let afterMidnight = november2(23, 59) + 120
        #expect(tally.count(on: afterMidnight, calendar: calendar) == 0)

        tally.recordFocusInterval(at: afterMidnight, calendar: calendar)
        #expect(tally.count(on: afterMidnight, calendar: calendar) == 1)
    }

    @Test func survivesReload() {
        let defaults = freshDefaults()
        var tally = DailyTally()
        tally.recordFocusInterval(at: november2(9), calendar: calendar)
        tally.recordFocusInterval(at: november2(10), calendar: calendar)
        tally.save(to: defaults)

        #expect(DailyTally(defaults: defaults).count(on: november2(17), calendar: calendar) == 2)
        #expect(DailyTally(defaults: freshDefaults()).count(on: november2(17), calendar: calendar) == 0)
    }
}

private func freshDefaults() -> UserDefaults {
    let suite = "DailyTallyTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
