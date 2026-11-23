import BtmxFocusCore
import Testing

struct ClockEntryTests {
    @Test(arguments: [
        ("15", 15) as (String, Int64), // seconds
        ("1515", 915),
        ("130", 90),
        ("90", 90), // carries over
        (" 15 ", 15),
    ])
    func readsDigitsLikeAMicrowave(text: String, seconds: Int64) {
        #expect(ClockEntry.duration(from: text) == .seconds(seconds))
    }

    @Test(arguments: [
        ("15:0", 900) as (String, Int64),
        ("15:", 900),
        ("15:00", 900),
        (":30", 30),
        ("5:3", 303),
        ("1:00:00", 3600),
        ("15.30", 930),
        ("15,30", 930),
        ("15 30", 930),
        ("15  30", 930),
        ("15 : 30", 930),
        ("1 30 0", 5400),
    ])
    func readsSeparatedTimes(text: String, seconds: Int64) {
        #expect(ClockEntry.duration(from: text) == .seconds(seconds))
    }

    @Test(arguments: [
        ("25m", 1500) as (String, Int64),
        ("25 min", 1500),
        ("25M", 1500),
        ("1h", 3600),
        ("1h30", 5400),
        ("1h 30m", 5400),
        ("1.5h", 5400),
        ("1,5h", 5400),
        ("90s", 90),
        ("2m30", 150),
        ("2m 30s", 150),
        ("2 min 30 sec", 150),
        ("25мин", 1500),
        ("1ч 15м", 4500),
        ("40с", 40),
    ])
    func readsUnits(text: String, seconds: Int64) {
        #expect(ClockEntry.duration(from: text) == .seconds(seconds))
    }

    @Test(arguments: [
        "", "0", "00:00", ":", "1:2:3:4", "12a", "-5", "24:00:01", "1234567890123",
        "h", "5x", "30 1h", "1s30", "25h",
    ])
    func rejectsWhatIsNotATime(text: String) {
        #expect(ClockEntry.duration(from: text) == nil)
    }
}
