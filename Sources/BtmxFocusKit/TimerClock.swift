import CoreGraphics
import Foundation

/// Wall-clock time, waiting for it, and how long the user has been away, so
/// tests can drive `TimerModel` with a fake clock.
@MainActor
public protocol TimerClock: AnyObject {
    var now: Date { get }
    /// Time since the last keyboard or mouse input.
    var idleTime: Duration { get }
    /// Returns at `deadline` (or soon after), or throws when the task is cancelled.
    func sleep(until deadline: Date) async throws
}

/// The real clock.
public final class SystemClock: TimerClock {
    public init() {}

    public var now: Date { Date() }

    /// Read from the window server; needs no permission.
    public var idleTime: Duration {
        // ~0 is kCGAnyInputEventType: any keyboard, mouse or tablet event.
        guard let anyInput = CGEventType(rawValue: ~0) else { return .zero }
        return .seconds(CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput))
    }

    public func sleep(until deadline: Date) async throws {
        let delay = max(0, deadline.timeIntervalSinceNow)
        try await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(50))
    }
}
