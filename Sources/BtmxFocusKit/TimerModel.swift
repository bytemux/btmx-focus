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
    /// Focus intervals completed today, saved on every change.
    public private(set) var tally: DailyTally {
        didSet { tally.save(to: defaults) }
    }

    @ObservationIgnored private let clock: TimerClock
    @ObservationIgnored private let signaler: PhaseSignalSink
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var displayAsleep = false
    @ObservationIgnored private var screenLocked = false
    /// Between the Mac going to sleep and the catch-up at wake: a phase
    /// completed then ended while asleep, and a Focus that did doesn't count
    /// towards today.
    @ObservationIgnored private var asleep = false
    /// While nobody can see the menu bar, skip per-second redraws and wake only
    /// at the phase end.
    private var secondsVisible: Bool { !displayAsleep && !screenLocked }

    /// The notification centers default to the system ones: NSWorkspace's
    /// (sleep, wake, display), the distributed one (screen lock) and the default
    /// one (system clock changes). The daily tally is kept in `defaults`; the
    /// default calendar follows time-zone changes, so "today" ends at the
    /// local midnight of wherever the Mac is now.
    public init(
        engine: TimerEngine = TimerEngine(),
        clock: TimerClock = SystemClock(),
        signaler: PhaseSignalSink,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        distributedCenter: NotificationCenter = DistributedNotificationCenter.default(),
        defaultCenter: NotificationCenter = .default
    ) {
        self.engine = engine
        self.clock = clock
        self.signaler = signaler
        self.defaults = defaults
        self.calendar = calendar
        tally = DailyTally(defaults: defaults)
        now = clock.now
        observeSystem(workspace: workspaceCenter, distributed: distributedCenter, local: defaultCenter)
    }

    public var state: TimerState { engine.state }
    public var remaining: Duration { engine.remaining(at: now) }
    public var clockText: String { ClockFormat.string(for: remaining) }
    /// Elapsed fraction of the phase, for the progress ring.
    public var progress: Double { engine.progress(at: now) }
    /// "Today n/target": read at the real time, so a popover opened after
    /// midnight shows 0 even if the timer sat Ready since yesterday.
    public var todayCount: Int { tally.count(on: clock.now, calendar: calendar) }
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

    /// New phase lengths from Settings: a Ready phase shows its new length at
    /// once; a Running or Paused phase whose length changed goes back to Ready.
    public func setSchedule(_ schedule: Schedule) {
        guard schedule != engine.schedule else { return }
        apply("schedule change") { engine, _ in engine.schedule = schedule }
    }

    /// Auto-start and skip-break-if-idle from Settings; they apply at the next phase end.
    public func setPhaseEnd(_ options: PhaseEndOptions) {
        guard options != engine.phaseEnd else { return }
        let action = "phase-end options autoStart \(options.autoStart) skipBreakIfIdle \(options.skipBreakIfIdle)"
        apply(action) { engine, _ in engine.phaseEnd = options }
    }

    /// What happens to the timer when the Mac sleeps, from Settings; applies at the next sleep.
    public func setSleepBehaviour(_ behaviour: SleepBehaviour) {
        guard behaviour != engine.sleepBehaviour else { return }
        apply("sleep behaviour \(behaviour.rawValue)") { engine, _ in engine.sleepBehaviour = behaviour }
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

    /// Completes every phase whose deadline has passed. Usually that is one,
    /// but after a sleep with keep counting and auto-start (or a clock jump)
    /// it can be several: each is logged, but only the latest is signalled,
    /// so waking doesn't play a burst of sounds (ADR 0015). A Focus that
    /// ended while the Mac slept doesn't count towards today.
    private func tick() {
        let date = clock.now
        now = date
        var latest: PhaseCompletion?
        while case let .running(_, deadline) = engine.state, deadline <= date {
            latest = completePhase(endingAt: deadline, now: date) ?? latest
        }
        if let latest {
            signaler.phaseCompleted(latest)
        }
    }

    private func completePhase(endingAt deadline: Date, now date: Date) -> PhaseCompletion? {
        // Idle time is read only if the engine asks (a Focus end with the option on).
        var idleTime = Duration.zero
        let event = engine.tick(now: date, idleTime: {
            idleTime = clock.idleTime
            return idleTime
        }())
        guard case let .phaseCompleted(completion) = event else { return nil }
        if completion.phase == .focus, !asleep {
            tally.recordFocusInterval(at: deadline, calendar: calendar)
        }
        let skipped = completion.skippedBreak.map { phase in
            ", \(PhaseStyle.name(of: phase)) skipped (idle \(ClockFormat.string(for: idleTime)))"
        } ?? ""
        CrashLog.record("phase end: \(PhaseStyle.name(of: completion.phase))\(skipped) → \(describe(at: date))")
        return completion
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
            MainActor.assumeIsolated {
                guard let model = self else { return }
                // A deadline that passed before its tick ran ends now, not
                // lost to the reset or paused at 00:00.
                model.tick()
                model.asleep = true
                model.apply("system sleep, \(model.engine.sleepBehaviour.rawValue)") { $0.systemWillSleep(now: $1) }
            }
        })
        observeVisibility(workspace, NSWorkspace.screensDidSleepNotification) { $0.displayAsleep = true }
        observeVisibility(workspace, NSWorkspace.screensDidWakeNotification) { $0.displayAsleep = false }
        observeVisibility(distributed, .init("com.apple.screenIsLocked")) { $0.screenLocked = true }
        observeVisibility(distributed, .init("com.apple.screenIsUnlocked")) { $0.screenLocked = false }
        // A tick may not have run while asleep: catch up with the deadline (keep counting).
        observeCatchUp(workspace, NSWorkspace.didWakeNotification, "system wake") { $0.asleep = false }
        observeCatchUp(local, .NSSystemClockDidChange, "system clock changed")
    }

    /// Ticks to catch up, then runs `afterwards`.
    private func observeCatchUp(
        _ center: NotificationCenter, _ name: Notification.Name, _ breadcrumb: String,
        afterwards: @escaping @MainActor (TimerModel) -> Void = { _ in }
    ) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let model = self else { return }
                CrashLog.record(breadcrumb)
                model.tick()
                afterwards(model)
                model.scheduleTicks()
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
