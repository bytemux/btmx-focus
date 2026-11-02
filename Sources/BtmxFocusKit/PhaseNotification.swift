import BtmxFocusCore
import Foundation

/// The end-of-phase notification text: what ended, and the actual next phase
/// with its length, e.g. "Time for a 15 min long break."
public struct PhaseNotification: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(_ completion: PhaseCompletion) {
        let length = Self.length(completion.nextDuration)
        title = switch completion.phase {
        case .focus: String(localized: "Focus done")
        case .rest: String(localized: "Break over")
        case .longRest: String(localized: "Long break over")
        }
        let next = switch completion.next {
        case .focus: String(localized: "Ready for \(length) of focus.")
        case .rest: String(localized: "Time for a \(length) break.")
        case .longRest: String(localized: "Time for a \(length) long break.")
        }
        body = switch completion.skippedBreak {
        case nil: next
        case .longRest: String(localized: "You were away for the long break. \(next)")
        case .focus, .rest: String(localized: "You were away for the break. \(next)")
        }
    }

    /// Whole minutes ("15 min"); shorter lengths (E2E) in seconds ("3 s").
    private static func length(_ duration: Duration) -> String {
        let seconds = duration.components.seconds
        return seconds % 60 == 0 && seconds > 0
            ? String(localized: "\(seconds / 60) min")
            : String(localized: "\(seconds) s")
    }
}
