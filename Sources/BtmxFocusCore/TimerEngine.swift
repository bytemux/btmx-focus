import Foundation

public enum Phase: Sendable, Equatable {
    case focus
    case rest
    case longRest

    /// The phase Skip leads to. A skipped Focus doesn't count towards the
    /// long break, so Skip from Focus is always Rest.
    public var next: Phase {
        switch self {
        case .focus: .rest
        case .rest, .longRest: .focus
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
    public var longRest: Duration
    /// A long break replaces Rest after this many Focus intervals.
    public var longRestEvery: Int

    public static let standard = Schedule(
        focus: .seconds(30 * 60), rest: .seconds(5 * 60), longRest: .seconds(15 * 60), longRestEvery: 4
    )

    public init(focus: Duration, rest: Duration, longRest: Duration, longRestEvery: Int) {
        self.focus = focus
        self.rest = rest
        self.longRest = longRest
        self.longRestEvery = longRestEvery
    }

    public func duration(of phase: Phase) -> Duration {
        switch phase {
        case .focus: focus
        case .rest: rest
        case .longRest: longRest
        }
    }
}

/// A phase that reached its phase end, and what comes next.
public struct PhaseCompletion: Sendable, Equatable {
    public let phase: Phase
    public let next: Phase
    /// The next phase's full length, for the notification text.
    public let nextDuration: Duration

    public init(phase: Phase, next: Phase, nextDuration: Duration) {
        self.phase = phase
        self.next = next
        self.nextDuration = nextDuration
    }
}

public enum TimerEvent: Sendable, Equatable {
    case phaseCompleted(PhaseCompletion)
}

/// Pure focus/rest state machine. Every time-dependent call takes `now`,
/// so callers (and tests) control the clock.
public struct TimerEngine: Sendable, Equatable {
    public private(set) var state: TimerState
    /// Takes effect at once for a Ready phase; a Running phase keeps its
    /// deadline and a Paused one its remaining time.
    public var schedule: Schedule
    /// Focus intervals since the cycle started (Reset or the last long break).
    public private(set) var focusIntervalsInCycle = 0

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
        focusIntervalsInCycle = 0
    }

    /// Completes the running phase once its deadline has passed. The next
    /// phase is loaded in `.ready` and waits for `play`.
    public mutating func tick(now: Date) -> TimerEvent? {
        guard case let .running(phase, endDate) = state, now >= endDate else { return nil }
        let next = phaseAfterCompleting(phase)
        state = .ready(next)
        return .phaseCompleted(PhaseCompletion(phase: phase, next: next, nextDuration: schedule.duration(of: next)))
    }

    /// Counts a Focus interval and picks Rest or, at the end of the cycle, a
    /// long break.
    private mutating func phaseAfterCompleting(_ phase: Phase) -> Phase {
        guard phase == .focus else { return .focus }
        focusIntervalsInCycle += 1
        guard focusIntervalsInCycle >= max(1, schedule.longRestEvery) else { return .rest }
        focusIntervalsInCycle = 0
        return .longRest
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
