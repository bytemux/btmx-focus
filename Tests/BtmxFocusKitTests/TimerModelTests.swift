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

    @Test func playAsksForNotificationPermission() {
        let harness = TimerHarness()
        harness.model.play()
        #expect(harness.signaler.authorizationRequests == 1)
    }
}
