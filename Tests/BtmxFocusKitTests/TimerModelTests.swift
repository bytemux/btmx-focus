import AppKit
import BtmxFocusCore
import BtmxFocusKit
import BtmxFocusTestSupport
import Testing

private let t0 = TimerHarness.t0

@MainActor
struct TimerModelTests {
    @Test func runningTimerCountsDownWithTheClock() async {
        let harness = TimerHarness()
        harness.model.play()
        #expect(harness.model.clockText == "30:00")
        await harness.clock.advance(by: 1)
        #expect(harness.model.clockText == "29:59")
        await harness.clock.advance(by: 346)
        #expect(harness.model.clockText == "24:13")
    }

    @Test func progressFillsWithTheClockAndHoldsWhilePaused() async {
        let harness = TimerHarness()
        #expect(harness.model.progress == 0)
        harness.model.play()
        await harness.clock.advance(by: 900)
        #expect(harness.model.progress == 0.5)
        harness.model.pause()
        await harness.clock.advance(by: 600)
        #expect(harness.model.progress == 0.5)
    }

    @Test func phaseEndSignalsOnceAndLoadsTheNextPhaseInReady() async {
        let harness = TimerHarness()
        harness.model.play()
        await harness.clock.advance(by: 1800)
        #expect(harness.signaler.completedPhases == [.focus])
        #expect(harness.model.state == .ready(.rest))
        #expect(harness.model.clockText == "05:00")

        // Nothing else fires while Ready, whatever wakes the model.
        await harness.clock.advance(by: 600)
        harness.postClockChange()
        harness.post(workspace: NSWorkspace.screensDidWakeNotification)
        #expect(harness.signaler.completedPhases == [.focus])
        #expect(harness.model.state == .ready(.rest))

        harness.model.play()
        await harness.clock.advance(by: 300)
        #expect(harness.signaler.completedPhases == [.focus, .rest])
        #expect(harness.model.state == .ready(.focus))
    }

    @Test func phaseEndWhileNobodyCanSeeTheScreenStillSignals() async {
        let harness = TimerHarness()
        harness.model.play()
        harness.post(distributed: "com.apple.screenIsLocked")
        await harness.clock.advance(by: 1800)
        #expect(harness.signaler.completedPhases == [.focus])
        #expect(harness.model.state == .ready(.rest))
    }

    @Test func lockedScreenSkipsPerSecondTicksAndUnlockCatchesUp() async {
        let harness = TimerHarness()
        harness.model.play()
        harness.post(distributed: "com.apple.screenIsLocked")
        await harness.clock.advance(by: 1)
        await harness.clock.advance(by: 1)
        #expect(harness.model.clockText == "30:00")

        harness.post(distributed: "com.apple.screenIsUnlocked")
        #expect(harness.model.clockText == "29:58")
        await harness.clock.advance(by: 1)
        #expect(harness.model.clockText == "29:57")
    }

    @Test func sleepingDisplaySkipsPerSecondTicksAndWakeCatchesUp() async {
        let harness = TimerHarness()
        harness.model.play()
        harness.post(workspace: NSWorkspace.screensDidSleepNotification)
        await harness.clock.advance(by: 60)
        #expect(harness.model.clockText == "30:00")

        harness.post(workspace: NSWorkspace.screensDidWakeNotification)
        #expect(harness.model.clockText == "29:00")
        await harness.clock.advance(by: 1)
        #expect(harness.model.clockText == "28:59")
    }

    @Test func togglePlayPauseAlternatesRunningAndPaused() async {
        let harness = TimerHarness()
        harness.model.togglePlayPause()
        #expect(harness.model.isRunning)
        await harness.clock.advance(by: 10)
        harness.model.togglePlayPause()
        #expect(harness.model.state == .paused(.focus, remaining: .seconds(1790)))
        harness.model.togglePlayPause()
        #expect(harness.model.isRunning)
        #expect(harness.model.clockText == "29:50")
    }

    @Test func clockChangeReTicks() {
        let harness = TimerHarness()
        harness.model.play()
        harness.clock.set(t0 + 600)
        harness.postClockChange()
        #expect(harness.model.clockText == "20:00")

        // A jump past the deadline completes the phase at once.
        harness.clock.set(t0 + 5000)
        harness.postClockChange()
        #expect(harness.signaler.completedPhases == [.focus])
        #expect(harness.model.state == .ready(.rest))
    }

    @Test func resetIsDisabledOnlyInReadyFocus() {
        let harness = TimerHarness()
        #expect(!harness.model.canReset)
        harness.model.play()
        #expect(harness.model.canReset)
        harness.model.pause()
        #expect(harness.model.canReset)
        harness.model.reset()
        #expect(!harness.model.canReset)
        harness.model.skip()
        #expect(harness.model.state == .ready(.rest))
        #expect(harness.model.canReset)
    }

    @Test func newScheduleShowsAtOnceWhileReadyAndRestartsTheChangedPhase() async {
        let harness = TimerHarness()
        var preferences = Preferences()
        preferences.focusMinutes = 50
        preferences.shortRestMinutes = 10
        harness.model.setSchedule(preferences.schedule)
        #expect(harness.model.clockText == "50:00")

        harness.model.play()
        await harness.clock.advance(by: 60)
        preferences.longRestMinutes = 30
        harness.model.setSchedule(preferences.schedule)
        #expect(harness.model.clockText == "49:00")

        preferences.focusMinutes = 45
        harness.model.setSchedule(preferences.schedule)
        #expect(harness.model.state == .ready(.focus))
        #expect(harness.model.clockText == "45:00")

        harness.model.play()
        await harness.clock.advance(by: 45 * 60)
        #expect(harness.signaler.completions == [
            PhaseCompletion(phase: .focus, next: .rest, nextDuration: .seconds(600)),
        ])
        #expect(harness.model.clockText == "10:00")
    }

    @Test func longBreakFollowsTheLastFocusOfTheCycle() async {
        let harness = TimerHarness()
        var preferences = Preferences()
        preferences.focusMinutes = 1
        preferences.longRestEvery = 2
        harness.model.setSchedule(preferences.schedule)
        for _ in 0 ..< 2 {
            harness.model.play()
            await harness.clock.advance(by: 60)
            if harness.model.state == .ready(.rest) {
                harness.model.skip()
            }
        }
        #expect(harness.model.state == .ready(.longRest))
        #expect(harness.model.clockText == "15:00")
        #expect(harness.signaler.completions.last?.next == .longRest)
    }

    @Test func playAsksForNotificationPermission() {
        let harness = TimerHarness()
        harness.model.play()
        #expect(harness.signaler.authorizationRequests == 1)
    }

    @Test func awayThroughAFocusEndGoesStraightToFocus() async {
        let harness = TimerHarness()
        harness.model.setPhaseEnd(PhaseEndOptions(skipBreakIfIdle: true))
        harness.model.play()
        await harness.clock.advance(by: 1700)
        harness.clock.idleTime = .seconds(5 * 60)
        await harness.clock.advance(by: 100)
        #expect(harness.signaler.completions == [PhaseCompletion(
            phase: .focus, next: .focus, nextDuration: .seconds(1800), skippedBreak: .rest
        )])
        #expect(harness.model.state == .ready(.focus))
    }

    @Test func autoStartKeepsTheCycleRunning() async {
        let harness = TimerHarness()
        harness.model.setPhaseEnd(PhaseEndOptions(autoStart: true))
        harness.model.play()
        await harness.clock.advance(by: 1800)
        #expect(harness.model.state == .running(.rest, endDate: t0 + 2100))
        await harness.clock.advance(by: 300)
        #expect(harness.signaler.completedPhases == [.focus, .rest])
        #expect(harness.model.state == .running(.focus, endDate: t0 + 3900))
        #expect(harness.model.clockText == "30:00")
    }

    @Test func completedFocusIntervalsCountTowardsToday() async {
        let harness = TimerHarness()
        #expect(harness.model.todayCount == 0)
        harness.model.play()
        await harness.clock.advance(by: 1800)
        #expect(harness.model.todayCount == 1)

        // A completed Rest and a skipped Focus don't count.
        harness.model.play()
        await harness.clock.advance(by: 300)
        harness.model.skip()
        #expect(harness.model.state == .ready(.rest))
        #expect(harness.model.todayCount == 1)
    }

    @Test func todayCountRestartsAtMidnightAndSurvivesRelaunch() async {
        let harness = TimerHarness()
        harness.model.play()
        await harness.clock.advance(by: 1800)

        let relaunched = TimerHarness(defaults: harness.defaults)
        #expect(relaunched.model.todayCount == 1)

        // t0 is 13:46 UTC; 11 hours on is the next day.
        relaunched.clock.set(t0 + 11 * 3600)
        #expect(relaunched.model.todayCount == 0)
    }
}

/// Sleep behaviour (ADR 0015) and the daily tally across a sleep.
@MainActor
struct TimerModelSleepTests {
    @Test(arguments: [
        TimerState.ready(.focus),
        .ready(.rest),
        .running(.focus, endDate: t0 + 600),
        .running(.rest, endDate: t0 + 60),
        .paused(.focus, remaining: .seconds(90)),
    ])
    func systemSleepResetsToReadyFocusByDefault(state: TimerState) {
        let harness = TimerHarness(engine: TimerEngine(state: state))
        harness.post(workspace: NSWorkspace.willSleepNotification)
        #expect(harness.model.state == .ready(.focus))
        #expect(harness.model.clockText == "30:00")
    }

    @Test func sleepWithPauseKeepsTheRemainingTimeThroughTheNight() async {
        let harness = TimerHarness()
        harness.model.setSleepBehaviour(.pause)
        harness.model.play()
        await harness.clock.advance(by: 600)
        harness.post(workspace: NSWorkspace.willSleepNotification)
        await harness.clock.advance(by: 8 * 3600)
        harness.post(workspace: NSWorkspace.didWakeNotification)
        #expect(harness.model.state == .paused(.focus, remaining: .seconds(1200)))
        #expect(harness.model.clockText == "20:00")
        #expect(harness.signaler.completions.isEmpty)
    }

    @Test(arguments: [SleepBehaviour.reset, .pause])
    func sleepJustAfterADeadlineItsTickMissedStillEndsThePhase(behaviour: SleepBehaviour) {
        let harness = TimerHarness()
        harness.model.setSleepBehaviour(behaviour)
        harness.model.play()

        // The deadline has passed, but its tick hasn't run yet.
        harness.clock.set(t0 + 1800.02)
        harness.post(workspace: NSWorkspace.willSleepNotification)
        #expect(harness.signaler.completedPhases == [.focus])
        #expect(harness.model.todayCount == 1)
        #expect(harness.model.state == (behaviour == .pause ? .ready(.rest) : .ready(.focus)))
    }

    @Test func sleepWithKeepCountingEndsThePhaseOnWakeWithOneSignal() async {
        let harness = TimerHarness()
        harness.model.setSleepBehaviour(.keepCounting)
        harness.model.play()
        await harness.clock.advance(by: 600)
        harness.post(workspace: NSWorkspace.willSleepNotification)
        #expect(harness.model.isRunning)

        // No tick runs while the Mac sleeps; the wake catches up.
        harness.clock.set(t0 + 8 * 3600)
        harness.post(workspace: NSWorkspace.didWakeNotification)
        #expect(harness.signaler.completedPhases == [.focus])
        #expect(harness.model.state == .ready(.rest))
        #expect(harness.model.todayCount == 1)
    }

    @Test func wakePastSeveralAutoStartedDeadlinesSignalsOnlyTheLatest() {
        let harness = TimerHarness()
        harness.model.setSleepBehaviour(.keepCounting)
        harness.model.setPhaseEnd(PhaseEndOptions(autoStart: true))
        harness.model.play()
        harness.post(workspace: NSWorkspace.willSleepNotification)

        // Focus ends at +30 min, Rest +35, Focus +65, Rest +70, Focus +100, Rest +105.
        harness.clock.set(t0 + 2 * 3600)
        harness.post(workspace: NSWorkspace.didWakeNotification)
        #expect(harness.signaler.completions == [
            PhaseCompletion(phase: .rest, next: .focus, nextDuration: .seconds(1800)),
        ])
        #expect(harness.model.state == .running(.focus, endDate: t0 + 135 * 60))
        #expect(harness.model.clockText == "15:00")
        #expect(harness.model.todayCount == 3)
    }

    @Test func focusEndedWhileAsleepCountsForTheDayItEnded() {
        let harness = TimerHarness()
        harness.model.setSleepBehaviour(.keepCounting)
        harness.model.play()
        harness.post(workspace: NSWorkspace.willSleepNotification)

        // t0 is 13:46 UTC: Focus ends today, the Mac wakes tomorrow.
        harness.clock.set(t0 + 11 * 3600)
        harness.post(workspace: NSWorkspace.didWakeNotification)
        #expect(harness.signaler.completedPhases == [.focus])
        #expect(harness.model.todayCount == 0)
    }
}
