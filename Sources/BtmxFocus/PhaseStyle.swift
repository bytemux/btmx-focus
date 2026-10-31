import AppKit
import BtmxFocusCore

/// Names and symbols shown for each timer state.
enum PhaseStyle {
    static func name(of phase: Phase) -> String {
        switch phase {
        case .focus: String(localized: "Focus")
        case .rest: String(localized: "Rest")
        }
    }

    /// Ready shows the outline symbol, running the filled one, so a glance
    /// tells whether the clock is moving.
    static func statusSymbol(for state: TimerState) -> String {
        switch state {
        case .ready(.focus): "timer.circle"
        case .running(.focus, _): "timer.circle.fill"
        case .ready(.rest): "cup.and.saucer"
        case .running(.rest, _): "cup.and.saucer.fill"
        case .paused: "pause.circle"
        }
    }

    /// Menu-bar icon colour while a phase is running; `nil` means the default
    /// template look.
    static func runningColor(for state: TimerState) -> NSColor? {
        switch state {
        case .running(.focus, _): .systemRed
        case .running(.rest, _): .systemGreen
        case .ready, .paused: nil
        }
    }

    static func stateName(of state: TimerState) -> String {
        switch state {
        case .ready: String(localized: "ready")
        case .running: String(localized: "running")
        case .paused: String(localized: "paused")
        }
    }

    /// e.g. "Focus, running, 24 minutes, 13 seconds remaining".
    static func accessibilityLabel(state: TimerState, remaining: Duration) -> String {
        let seconds = ClockFormat.displayedSeconds(remaining)
        let time = Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return String(localized: "\(name(of: state.phase)), \(stateName(of: state)), \(time) remaining")
    }
}
