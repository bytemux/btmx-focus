import AppKit
import BtmxFocusCore
import BtmxFocusKit
import BtmxFocusTestSupport
import Testing

private let t0 = TimerHarness.t0

@MainActor
struct TimerModelTests {
    @Test(arguments: [
        TimerState.ready(.focus),
        .ready(.rest),
        .running(.focus, endDate: t0 + 600),
        .running(.rest, endDate: t0 + 60),
        .paused(.focus, remaining: .seconds(90)),
    ])
    func systemSleepResetsToReadyFocus(state: TimerState) {
        let harness = TimerHarness(engine: TimerEngine(state: state))
        harness.post(workspace: NSWorkspace.willSleepNotification)
        #expect(harness.model.state == .ready(.focus))
        #expect(harness.model.clockText == "30:00")
    }

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

    @Test func newScheduleShowsAtOnceWhileReadyAndKeepsTheCountdownOtherwise() async {
        let harness = TimerHarness()
        var preferences = Preferences()
        preferences.focusMinutes = 50
        preferences.shortRestMinutes = 10
        harness.model.setSchedule(preferences.schedule)
        #expect(harness.model.clockText == "50:00")

        harness.model.play()
        await harness.clock.advance(by: 60)
        preferences.focusMinutes = 1
        harness.model.setSchedule(preferences.schedule)
        #expect(harness.model.clockText == "49:00")

        await harness.clock.advance(by: 49 * 60)
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
