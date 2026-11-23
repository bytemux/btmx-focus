import BtmxFocusCore
import Testing

struct ClockEntryTests {
    @Test(arguments: [
        ("15", 15) as (String, Int64), // seconds
        ("1515", 915),
        ("130", 90),
        ("90", 90), // carries over
        ("15:0", 900),
        ("15:", 900),
        ("15:00", 900),
        (":30", 30),
        ("5:3", 303),
        ("1:00:00", 3600),
        ("12345", 7425),
    ])
    func readsTypedTimes(text: String, seconds: Int64) {
        #expect(ClockEntry.duration(from: text) == .seconds(seconds))
    }

    @Test(arguments: ["", "0", "00:00", ":", "1:2:3:4", "12a", "-5", "24:00:01", "123456789"])
    func rejectsWhatIsNotATime(text: String) {
        #expect(ClockEntry.duration(from: text) == nil)
    }
}
