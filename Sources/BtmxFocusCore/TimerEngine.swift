import Foundation

public enum Phase: Sendable, Equatable {
    case focus
    case rest

    public var next: Phase {
        switch self {
        case .focus: .rest
        case .rest: .focus
        }
    }
}

public enum TimerState: Sendable, Equatable {
    case ready(Phase)
    case running(Phase, endDate: Date)
    case paused(Phase, remaining: Duration)

    public var phase: Phase {
        switch self {
        case let .ready(phase), let .running(phase, _), let .paused(phase, _):
            phase
        }
    }
}

public struct Schedule: Sendable, Equatable {
    public var focus: Duration
    public var rest: Duration

    public static let standard = Schedule(focus: .seconds(30 * 60), rest: .seconds(5 * 60))

    public init(focus: Duration, rest: Duration) {
        self.focus = focus
        self.rest = rest
    }

    public func duration(of phase: Phase) -> Duration {
        switch phase {
        case .focus: focus
        case .rest: rest
        }
    }
}

public enum TimerEvent: Sendable, Equatable {
    case phaseCompleted(Phase)
}

/// Pure focus/rest state machine. Every time-dependent call takes `now`,
/// so callers (and tests) control the clock.
public struct TimerEngine: Sendable, Equatable {
    public private(set) var state: TimerState
    public let schedule: Schedule

    public init(schedule: Schedule = .standard, state: TimerState = .ready(.focus)) {
        self.schedule = schedule
        self.state = state
    }

    public mutating func play(now: Date) {
        switch state {
        case let .ready(phase):
            state = .running(phase, endDate: now + schedule.duration(of: phase))
        case let .paused(phase, remaining):
            state = .running(phase, endDate: now + remaining)
        case .running:
            break
        }
    }

    public mutating func pause(now: Date) {
        guard case let .running(phase, _) = state else { return }
        state = .paused(phase, remaining: remaining(at: now))
    }

    public mutating func skip() {
        state = .ready(state.phase.next)
    }

    /// Back to the start of a focus phase. Also used when the Mac goes to sleep.
    public mutating func reset() {
        state = .ready(.focus)
    }

    /// Completes the running phase once its deadline has passed. The next
    /// phase is loaded in `.ready` and waits for `play`.
    public mutating func tick(now: Date) -> TimerEvent? {
        guard case let .running(phase, endDate) = state, now >= endDate else { return nil }
        state = .ready(phase.next)
        return .phaseCompleted(phase)
    }

    public func remaining(at now: Date) -> Duration {
        switch state {
        case let .ready(phase):
            schedule.duration(of: phase)
        case let .running(_, endDate):
            max(.zero, .seconds(endDate.timeIntervalSince(now)))
        case let .paused(_, remaining):
            remaining
        }
    }

    /// How much of the current phase has elapsed, from 0 (Ready) to 1 (at the
    /// deadline). The progress ring shows the rest, `1 - progress`.
    public func progress(at now: Date) -> Double {
        let total = schedule.duration(of: state.phase).timeInterval
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(at: now).timeInterval / total))
    }

    /// The next instant the displayed whole-second value changes (or the
    /// phase ends), or `nil` when the clock isn't moving. With
    /// `secondsVisible: false` (nobody can see the display) only the phase end
    /// matters, so it returns the deadline itself.
    public func nextChangeDate(after now: Date, secondsVisible: Bool = true) -> Date? {
        guard case let .running(_, endDate) = state else { return nil }
        let left = endDate.timeIntervalSince(now)
        guard left > 0 else { return now }
        guard secondsVisible else { return endDate }
        return endDate - (left.rounded(.up) - 1)
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let parts = components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }
}

extension Date {
    static func + (date: Date, duration: Duration) -> Date {
        date.addingTimeInterval(duration.timeInterval)
    }
}
