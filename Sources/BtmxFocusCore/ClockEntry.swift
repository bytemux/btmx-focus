import Foundation

/// What the user types into the popover clock to set the remaining time.
///
/// - Digits only, read like a microwave: the last two are seconds, the rest
///   minutes. `15` → 00:15, `1515` → 15:15, `130` → 01:30.
/// - With a colon, `m:s` or `h:m:s`; an empty part is zero.
///   `15:0` and `15:` → 15:00, `:30` → 00:30, `1:00:00` → 1:00:00.
///
/// Seconds or minutes over 59 carry over (`90` → 01:30). Zero, anything
/// else, or more than 24 hours is not a time.
public enum ClockEntry {
    public static let maxLength = 8
    public static let maxDuration = Duration.seconds(24 * 3600)

    /// The characters the clock accepts while editing.
    public static let allowedCharacters = Set("0123456789:")

    public static func duration(from text: String) -> Duration? {
        guard !text.isEmpty, text.count <= maxLength, text.allSatisfy(allowedCharacters.contains) else {
            return nil
        }
        let parts: [Int]
        if text.contains(":") {
            let fields = text.split(separator: ":", omittingEmptySubsequences: false)
            guard fields.count <= 3 else { return nil }
            parts = fields.map { Int($0) ?? 0 }
        } else {
            let value = Int(text) ?? 0
            parts = [value / 100, value % 100]
        }
        // [s], [m, s] or [h, m, s] → seconds.
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        let duration = Duration.seconds(seconds)
        guard seconds > 0, duration <= maxDuration else { return nil }
        return duration
    }
}
