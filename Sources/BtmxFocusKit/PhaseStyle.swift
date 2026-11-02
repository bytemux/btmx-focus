import BtmxFocusCore
import Foundation

/// Names shown for each timer state.
public enum PhaseStyle {
    public static func name(of phase: Phase) -> String {
        switch phase {
        case .focus: String(localized: "Focus")
        case .rest: String(localized: "Rest")
        case .longRest: String(localized: "Long break")
        }
    }

    public static func stateName(of state: TimerState) -> String {
        switch state {
        case .ready: String(localized: "ready")
        case .running: String(localized: "running")
        case .paused: String(localized: "paused")
        }
    }

    /// e.g. "Focus, running, 24 minutes, 13 seconds remaining".
    public static func accessibilityLabel(state: TimerState, remaining: Duration) -> String {
        let seconds = ClockFormat.displayedSeconds(remaining)
        let time = Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return String(localized: "\(name(of: state.phase)), \(stateName(of: state)), \(time) remaining")
    }
}
