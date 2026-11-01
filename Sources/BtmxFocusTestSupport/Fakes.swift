import AppKit
import BtmxFocusCore
import BtmxFocusKit

// Test doubles shared by the unit and snapshot test targets.

/// A clock that moves only when told to. Sleepers wake when `advance` passes
/// their deadline.
@MainActor
public final class FakeClock: TimerClock {
    public private(set) var now: Date
    private var sleepers: [UUID: (deadline: Date, continuation: CheckedContinuation<Void, Error>)] = [:]

    public init(now: Date) {
        self.now = now
    }

    public func sleep(until deadline: Date) async throws {
        guard deadline > now else { return }
        let token = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleepers[token] = (deadline, continuation)
            }
        } onCancel: {
            Task { @MainActor in
                self.sleepers.removeValue(forKey: token)?.continuation.resume(throwing: CancellationError())
            }
        }
    }

    /// Moves the clock without waking sleepers, like a system clock change.
    public func set(_ date: Date) {
        now = date
    }

    /// Lets pending tasks reach their sleep, moves the clock, wakes sleepers
    /// that are due and lets them run.
    public func advance(by seconds: TimeInterval) async {
        await settle()
        now += seconds
        for (token, sleeper) in sleepers where sleeper.deadline <= now {
            sleepers.removeValue(forKey: token)
            sleeper.continuation.resume()
        }
        await settle()
    }
}

/// Lets tasks woken on the main actor run. A woken tick task needs a few hops
/// (resume, tick, schedule the next sleep); 20 yields leaves ample headroom.
/// If `TimerModel` ever adds awaits to its tick loop and tests turn flaky,
/// raise this or switch to a deterministic executor.
@MainActor
public func settle() async {
    for _ in 0 ..< 20 {
        await Task.yield()
    }
}

@MainActor
public final class RecordingSignaler: PhaseSignalSink {
    public private(set) var completedPhases: [Phase] = []
    public private(set) var authorizationRequests = 0

    public init() {}

    public func requestAuthorizationIfNeeded() {
        authorizationRequests += 1
    }

    public func phaseCompleted(_ phase: Phase) {
        completedPhases.append(phase)
    }
}

/// An empty, per-test defaults domain and its name.
public func freshDefaults() -> (defaults: UserDefaults, suite: String) {
    let suite = "BtmxFocusTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (defaults, suite)
}

/// A `TimerModel` wired to a fake clock, a recording signaler and private
/// notification centers that tests post system events to.
@MainActor
public struct TimerHarness {
    public nonisolated static let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    public let clock = FakeClock(now: t0)
    public let signaler = RecordingSignaler()
    public let workspace = NotificationCenter()
    public let distributed = NotificationCenter()
    public let local = NotificationCenter()
    public let model: TimerModel

    public init(engine: TimerEngine = TimerEngine()) {
        model = TimerModel(
            engine: engine, clock: clock, signaler: signaler,
            workspaceCenter: workspace, distributedCenter: distributed, defaultCenter: local
        )
    }

    public func post(workspace name: Notification.Name) {
        workspace.post(name: name, object: nil)
    }

    public func post(distributed name: String) {
        distributed.post(name: .init(name), object: nil)
    }

    public func postClockChange() {
        local.post(name: .NSSystemClockDidChange, object: nil)
    }
}
