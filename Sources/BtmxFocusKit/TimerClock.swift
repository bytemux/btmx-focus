import Foundation

/// Wall-clock time and waiting for it, so tests can drive `TimerModel` with a
/// fake clock.
@MainActor
public protocol TimerClock: AnyObject {
    var now: Date { get }
    /// Returns at `deadline` (or soon after), or throws when the task is cancelled.
    func sleep(until deadline: Date) async throws
}

/// The real clock.
public final class SystemClock: TimerClock {
    public init() {}

    public var now: Date { Date() }

    public func sleep(until deadline: Date) async throws {
        let delay = max(0, deadline.timeIntervalSinceNow)
        try await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(50))
    }
}
