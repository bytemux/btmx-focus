import AppKit
import BtmxFocusCore
import Observation

/// Owns the engine, drives display ticks and reacts to system events.
@MainActor
@Observable
final class TimerModel {
    private(set) var engine = TimerEngine()
    /// Last time the display was refreshed; views derive the remaining time from it.
    private(set) var now = Date()

    @ObservationIgnored private let signaler: PhaseSignaler
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(signaler: PhaseSignaler) {
        self.signaler = signaler
        observeSystem()
    }

    var state: TimerState { engine.state }
    var remaining: Duration { engine.remaining(at: now) }
    var clockText: String { ClockFormat.string(for: remaining) }
    var isRunning: Bool { if case .running = state { true } else { false } }
    /// Not started yet: icon only, no time in the menu bar.
    var menuBarText: String? { if case .ready = state { nil } else { clockText } }

    func togglePlayPause() {
        if isRunning {
            pause()
        } else {
            play()
        }
    }

    func play() {
        apply("play") { $0.play(now: $1) }
        signaler.requestAuthorizationIfNeeded()
    }

    func pause() {
        apply("pause") { $0.pause(now: $1) }
    }

    func skip() {
        apply("skip") { engine, _ in engine.skip() }
    }

    func reset() {
        apply("reset") { engine, _ in engine.reset() }
    }

    /// Applies a user or system action and leaves a breadcrumb with the state change.
    private func apply(_ action: String, _ change: (inout TimerEngine, Date) -> Void) {
        let date = Date()
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
        let date = Date()
        now = date
        if case let .phaseCompleted(phase) = engine.tick(now: date) {
            CrashLog.record("phase end: \(PhaseStyle.name(of: phase)) → \(describe(at: date))")
            signaler.phaseCompleted(phase)
        }
    }

    /// Wakes only when the displayed second changes, and not at all unless running.
    private func scheduleTicks() {
        tickTask?.cancel()
        tickTask = nil
        guard isRunning else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let model = self, let fireDate = model.engine.nextChangeDate(after: Date()) else { return }
                let delay = max(0, fireDate.timeIntervalSinceNow)
                try? await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(50))
                guard !Task.isCancelled else { return }
                model.tick()
            }
        }
    }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply("system sleep, reset") { engine, _ in engine.reset() } }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                CrashLog.record("system clock changed")
                self?.tick()
                self?.scheduleTicks()
            }
        })
    }
}
