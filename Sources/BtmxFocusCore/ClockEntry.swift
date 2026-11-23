import Foundation

/// What the user types into the popover clock to set the remaining time.
///
/// - Digits only, read like a microwave: the last two are seconds, the rest
///   minutes. `15` → 00:15, `1515` → 15:15, `130` → 01:30.
/// - With separators (`:`, `.`, `,` or a space), `m:s` or `h:m:s`; an empty
///   part is zero. `15:0`, `15:` and `15 0` → 15:00, `:30` → 00:30,
///   `1:00:00` → 1:00:00.
/// - With units, in English or Russian, in any combination: `25m`,
///   `25 min`, `1h`, `1.5h`, `90s`, `25мин`, `1ч 15м`. A bare number after a
///   unit is the next smaller one: `1h30` → 1:30:00, `2m30` → 02:30.
///
/// Values over 59 carry over (`90` → 01:30). Zero, anything else, or more
/// than 24 hours is not a time.
public enum ClockEntry {
    public static let maxLength = 12
    public static let maxDuration = Duration.seconds(24 * 3600)

    public static func duration(from input: String) -> Duration? {
        let text = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty, text.count <= maxLength else { return nil }
        let seconds = text.contains(where: \.isLetter) ? withUnits(text) : withSeparators(text)
        guard let seconds, seconds >= 1, seconds <= maxDuration.timeInterval else { return nil }
        return .seconds(Int(seconds.rounded()))
    }

    /// Digits, optionally split by `:`, `.`, `,` or spaces into h:m:s.
    private static func withSeparators(_ text: String) -> TimeInterval? {
        let separators = CharacterSet(charactersIn: ":.,").union(.whitespaces)
        guard text.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) || separators.contains($0) })
        else { return nil }
        // Runs of spaces are one separator; `15 :30` is 15:30 too.
        let normalized = text
            .replacingOccurrences(of: "\\s*[:.,]\\s*|\\s+", with: ":", options: .regularExpression)
        guard normalized.contains(":") else {
            let value = Int(normalized) ?? 0
            return TimeInterval(value / 100 * 60 + value % 100)
        }
        let fields = normalized.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count <= 3 else { return nil }
        // [m, s] or [h, m, s] → seconds.
        return TimeInterval(fields.map { Int($0) ?? 0 }.reduce(0) { $0 * 60 + $1 })
    }

    /// Numbers each followed by a unit (`1h 30m`), or by nothing after a
    /// unit (`1h30`).
    private static func withUnits(_ text: String) -> TimeInterval? {
        var scanner = Substring(text)
        var total: TimeInterval = 0
        var previousUnit: TimeInterval?
        while !scanner.isEmpty {
            scanner = scanner.drop(while: \.isWhitespace)
            let number = scanner.prefix(while: { $0.isNumber || $0 == "." || $0 == "," })
            guard let value = Double(number.replacingOccurrences(of: ",", with: ".")) else { return nil }
            scanner = scanner.dropFirst(number.count).drop(while: \.isWhitespace)
            let word = scanner.prefix(while: \.isLetter)
            scanner = scanner.dropFirst(word.count)
            let unit: TimeInterval
            if let first = word.first {
                guard let named = units[first] else { return nil }
                unit = named
            } else {
                // `1h30`: minutes; `2m30`: seconds; a bare number first isn't allowed.
                guard let previousUnit, previousUnit > 1 else { return nil }
                unit = previousUnit / 60
            }
            total += value * unit
            previousUnit = unit
        }
        return total
    }

    /// Units by their first letter: h(ours), m(in), s(ec), ч(ас), м(ин), с(ек).
    private static let units: [Character: TimeInterval] = [
        "h": 3600, "ч": 3600, "m": 60, "м": 60, "s": 1, "с": 1,
    ]
}
