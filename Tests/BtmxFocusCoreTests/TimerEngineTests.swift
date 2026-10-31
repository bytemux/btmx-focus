@testable import BtmxFocusCore
import Foundation
import Testing

private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

private func at(_ seconds: TimeInterval) -> Date {
    t0.addingTimeInterval(seconds)
}

struct TimerEngineTests {
    @Test func startsReadyForFocusAtFullLength() {
        let engine = TimerEngine()
        #expect(engine.state == .ready(.focus))
        #expect(engine.remaining(at: t0) == .seconds(30 * 60))
        #expect(engine.nextChangeDate(after: t0) == nil)
    }

    @Test func playRunsUntilDeadline() {
        var engine = TimerEngine()
        engine.play(now: t0)
        #expect(engine.state == .running(.focus, endDate: at(1800)))
        #expect(engine.remaining(at: at(600)) == .seconds(1200))
        #expect(engine.tick(now: at(1799.9)) == nil)
    }

    @Test func playWhileRunningIsIgnored() {
        var engine = TimerEngine()
        engine.play(now: t0)
        engine.play(now: at(100))
        #expect(engine.state == .running(.focus, endDate: at(1800)))
    }

    @Test func phaseEndLoadsNextPhaseAndWaitsForPlay() {
        var engine = TimerEngine()
        engine.play(now: t0)
        #expect(engine.tick(now: at(1800)) == .phaseCompleted(.focus))
        #expect(engine.state == .ready(.rest))
        #expect(engine.remaining(at: at(5000)) == .seconds(5 * 60))
        #expect(engine.tick(now: at(5000)) == nil)

        engine.play(now: at(2000))
        #expect(engine.tick(now: at(2300)) == .phaseCompleted(.rest))
        #expect(engine.state == .ready(.focus))
    }

    @Test func pauseFreezesAndPlayResumes() {
        var engine = TimerEngine()
        engine.play(now: t0)
        engine.pause(now: at(600))
        #expect(engine.state == .paused(.focus, remaining: .seconds(1200)))
        #expect(engine.remaining(at: at(9999)) == .seconds(1200))
        #expect(engine.tick(now: at(9999)) == nil)

        engine.play(now: at(10000))
        #expect(engine.state == .running(.focus, endDate: at(11200)))
    }

    @Test(arguments: [
        TimerState.ready(.focus),
        .running(.focus, endDate: at(100)),
        .paused(.focus, remaining: .seconds(10)),
    ])
    func skipLoadsOtherPhaseInReady(state: TimerState) {
        var engine = TimerEngine(state: state)
        engine.skip()
        #expect(engine.state == .ready(.rest))
        engine.skip()
        #expect(engine.state == .ready(.focus))
    }

    @Test(arguments: [
        TimerState.ready(.rest),
        .running(.rest, endDate: at(100)),
        .paused(.focus, remaining: .seconds(10)),
    ])
    func resetReturnsToReadyFocus(state: TimerState) {
        var engine = TimerEngine(state: state)
        engine.reset()
        #expect(engine.state == .ready(.focus))
    }

    @Test func remainingNeverNegative() {
        let engine = TimerEngine(state: .running(.focus, endDate: t0))
        #expect(engine.remaining(at: at(5)) == .zero)
    }

    @Test func nextChangeIsWhenDisplayedSecondChanges() {
        let engine = TimerEngine(state: .running(.focus, endDate: at(10)))
        // 9.6 s left shows 10; it changes to 9 when 9 s are left.
        #expect(engine.nextChangeDate(after: at(0.4)) == at(1))
        // Exactly 5 s left shows 5; next change at 4 s left.
        #expect(engine.nextChangeDate(after: at(5)) == at(6))
        // Under a second left: next change is the deadline itself.
        #expect(engine.nextChangeDate(after: at(9.5)) == at(10))
        // Past the deadline: due now.
        #expect(engine.nextChangeDate(after: at(11)) == at(11))
    }
}

extension TimerEngineTests {
    @Test func nextChangeIsDeadlineWhenSecondsNotVisible() {
        let engine = TimerEngine(state: .running(.focus, endDate: at(1800)))
        #expect(engine.nextChangeDate(after: at(0.4), secondsVisible: false) == at(1800))
        #expect(engine.nextChangeDate(after: at(1801), secondsVisible: false) == at(1801))
        #expect(TimerEngine().nextChangeDate(after: t0, secondsVisible: false) == nil)
    }
}

struct ClockFormatTests {
    @Test(arguments: [
        (1800.0, "30:00"),
        (1799.4, "30:00"),
        (1799.0, "29:59"),
        (0.2, "00:01"),
        (0.0, "00:00"),
        (-3.0, "00:00"),
        (3600.0, "1:00:00"),
        (3725.0, "1:02:05"),
    ])
    func formatsRoundingUp(seconds: Double, expected: String) {
        #expect(ClockFormat.string(for: .seconds(seconds)) == expected)
    }
}
