import AppKit
import BtmxFocusCore
import Observation

/// Owns the engine, drives display ticks and reacts to system events.
@MainActor
@Observable
public final class TimerModel {
    public private(set) var engine: TimerEngine
    /// Last time the display was refreshed; views derive the remaining time from it.
    public private(set) var now: Date

    @ObservationIgnored private let clock: TimerClock
    @ObservationIgnored private let signaler: PhaseSignalSink
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var displayAsleep = false
    @ObservationIgnored private var screenLocked = false
    /// While nobody can see the menu bar, skip per-second redraws and wake only
    /// at the phase end.
    private var secondsVisible: Bool { !displayAsleep && !screenLocked }

    /// The notification centers default to the system ones: NSWorkspace's
    /// (sleep, display), the distributed one (screen lock) and the default
    /// one (system clock changes).
    public init(
        engine: TimerEngine = TimerEngine(),
        clock: TimerClock = SystemClock(),
        signaler: PhaseSignalSink,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        distributedCenter: NotificationCenter = DistributedNotificationCenter.default(),
        defaultCenter: NotificationCenter = .default
    ) {
        self.engine = engine
        self.clock = clock
        self.signaler = signaler
        now = clock.now
        observeSystem(workspace: workspaceCenter, distributed: distributedCenter, local: defaultCenter)
    }

    public var state: TimerState { engine.state }
    public var remaining: Duration { engine.remaining(at: now) }
    public var clockText: String { ClockFormat.string(for: remaining) }
    /// Elapsed fraction of the phase, for the progress ring.
    public var progress: Double { engine.progress(at: now) }
    public var isRunning: Bool { if case .running = state { true } else { false } }
    /// Nothing to reset back to at the start of a focus phase.
    public var canReset: Bool { state != .ready(.focus) }

    public func togglePlayPause() {
        if isRunning {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        apply("play") { $0.play(now: $1) }
        signaler.requestAuthorizationIfNeeded()
    }

    public func pause() {
        apply("pause") { $0.pause(now: $1) }
    }

    public func skip() {
        apply("skip") { engine, _ in engine.skip() }
    }

    public func reset() {
        apply("reset") { engine, _ in engine.reset() }
    }

    /// Applies a user or system action and leaves a breadcrumb with the state change.
    private func apply(_ action: String, _ change: (inout TimerEngine, Date) -> Void) {
        let date = clock.now
        let before = describe(at: date)
        change(&engine, date)
        now = date
        CrashLog.record("\(action): \(before) → \(describe(at: date))")
        scheduleTicks()
    }

    private func describe(at date: Date) -> String {
        let state = engine.state
        let time = ClockFormat.string(for: engine.remaining(at: date))
        return "\(PhaseStyle.name(of: state.phase)) \(PhaseStyle.stateName(of: state)) \(time)"
    }

    private func tick() {
        let date = clock.now
        now = date
        if case let .phaseCompleted(phase) = engine.tick(now: date) {
            CrashLog.record("phase end: \(PhaseStyle.name(of: phase)) → \(describe(at: date))")
            signaler.phaseCompleted(phase)
        }
    }

    /// Wakes only when the displayed second changes (or only at the phase end
    /// while the display can't be seen), and not at all unless running.
    private func scheduleTicks() {
        tickTask?.cancel()
        tickTask = nil
        guard isRunning else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let model = self,
                      let fireDate = model.engine.nextChangeDate(
                          after: model.clock.now, secondsVisible: model.secondsVisible
                      )
                else { return }
                try? await model.clock.sleep(until: fireDate)
                guard !Task.isCancelled else { return }
                model.tick()
            }
        }
    }

    private func observeSystem(
        workspace: NotificationCenter, distributed: NotificationCenter, local: NotificationCenter
    ) {
        observers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply("system sleep, reset") { engine, _ in engine.reset() } }
        })
        observeVisibility(workspace, NSWorkspace.screensDidSleepNotification) { $0.displayAsleep = true }
        observeVisibility(workspace, NSWorkspace.screensDidWakeNotification) { $0.displayAsleep = false }
        observeVisibility(distributed, .init("com.apple.screenIsLocked")) { $0.screenLocked = true }
        observeVisibility(distributed, .init("com.apple.screenIsUnlocked")) { $0.screenLocked = false }
        observers.append(local.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                CrashLog.record("system clock changed")
                self?.tick()
                self?.scheduleTicks()
            }
        })
    }

    private func observeVisibility(
        _ center: NotificationCenter, _ name: Notification.Name, update: @escaping @MainActor (TimerModel) -> Void
    ) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let model = self else { return }
                update(model)
                CrashLog.record("\(name.rawValue), seconds visible: \(model.secondsVisible)")
                model.tick()
                model.scheduleTicks()
            }
        })
    }
}
