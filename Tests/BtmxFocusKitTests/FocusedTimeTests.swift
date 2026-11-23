import AppKit
import BtmxFocusCore
import BtmxFocusKit
import BtmxFocusTestSupport
import Testing

/// Today's focused time: time spent Running in Focus, also when cut short.
@MainActor
struct FocusedTimeTests {
    @Test func countsRunningFocusLiveAndKeepsItAfterPause() async {
        let harness = TimerHarness()
        harness.model.play()
        await harness.clock.advance(by: 600)
        #expect(harness.model.todayFocusedTime == .seconds(600))
        harness.model.pause()
        await harness.clock.advance(by: 600)
        #expect(harness.model.todayFocusedTime == .seconds(600))
    }

    @Test func aSkippedFocusCountsAndBreaksDoNot() async {
        let harness = TimerHarness()
        harness.model.play()
        await harness.clock.advance(by: 300)
        harness.model.skip()
        harness.model.play()
        await harness.clock.advance(by: 300)
        #expect(harness.model.state == .ready(.focus))
        #expect(harness.model.todayFocusedTime == .seconds(300))
        #expect(harness.model.todayCount == 0)
    }

    @Test func aFullFocusIntervalCountsItsLength() async {
        let harness = TimerHarness()
        harness.model.play()
        await harness.clock.advance(by: 1800)
        #expect(harness.model.todayCount == 1)
        #expect(harness.model.todayFocusedTime == .seconds(1800))
        let relaunched = TimerHarness(defaults: harness.defaults)
        #expect(relaunched.model.todayFocusedTime == .seconds(1800))
    }

    @Test func autoStartedFocusCountsFromTheBreakDeadline() async {
        let harness = TimerHarness()
        harness.model.setPhaseEnd(PhaseEndOptions(autoStart: true))
        harness.model.play()
        await harness.clock.advance(by: 1800 + 300 + 60)
        #expect(harness.model.todayFocusedTime == .seconds(1800 + 60))
    }

    @Test func sleepIsNotFocusedTimeEvenWhenKeepCounting() async {
        let harness = TimerHarness()
        harness.model.setSleepBehaviour(.keepCounting)
        harness.model.play()
        await harness.clock.advance(by: 600)
        harness.post(workspace: NSWorkspace.willSleepNotification)
        harness.clock.set(harness.clock.now + 300)
        harness.post(workspace: NSWorkspace.didWakeNotification)
        #expect(harness.model.state == .running(.focus, endDate: TimerHarness.t0 + 1800))
        await harness.clock.advance(by: 100)
        #expect(harness.model.todayFocusedTime == .seconds(700))
    }

    @Test func settingTheTimeKeepsRunningAndCounting() async {
        let harness = TimerHarness()
        harness.model.play()
        await harness.clock.advance(by: 30)
        harness.model.setRemaining(.seconds(15))
        #expect(harness.model.clockText == "00:15")
        #expect(harness.model.isRunning)
        await harness.clock.advance(by: 15)
        #expect(harness.model.state == .ready(.rest))
        #expect(harness.model.todayCount == 1)
        #expect(harness.model.todayFocusedTime == .seconds(45))
    }
}

/// Reset Today's Progress: the dots and Focus Time start again, the timer doesn't.
@MainActor
struct ResetTodayTests {
    @Test func clearsTheDayButKeepsARunningFocusCounting() async {
        let harness = TimerHarness()
        #expect(!harness.model.canResetToday)
        harness.model.play()
        await harness.clock.advance(by: 1800)
        harness.model.skip()
        harness.model.play()
        await harness.clock.advance(by: 600)
        #expect(harness.model.todayCount == 1)
        #expect(harness.model.canResetToday)

        harness.model.resetToday()
        #expect(harness.model.todayCount == 0)
        #expect(harness.model.todayFocusedTime == .zero)
        #expect(harness.model.state == .running(.focus, endDate: TimerHarness.t0 + 3600))

        await harness.clock.advance(by: 60)
        #expect(harness.model.todayFocusedTime == .seconds(60))
        // Saved: a relaunch doesn't bring the old day back.
        #expect(TimerHarness(defaults: harness.defaults).model.todayCount == 0)
    }
}
