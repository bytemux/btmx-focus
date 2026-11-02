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
        #expect(engine.tick(now: at(1800)) == .phaseCompleted(
            PhaseCompletion(phase: .focus, next: .rest, nextDuration: .seconds(5 * 60))
        ))
        #expect(engine.state == .ready(.rest))
        #expect(engine.remaining(at: at(5000)) == .seconds(5 * 60))
        #expect(engine.tick(now: at(5000)) == nil)

        engine.play(now: at(2000))
        #expect(engine.tick(now: at(2300)) == .phaseCompleted(
            PhaseCompletion(phase: .rest, next: .focus, nextDuration: .seconds(30 * 60))
        ))
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

    @Test func progressIsTheElapsedFractionOfThePhase() {
        var engine = TimerEngine()
        #expect(engine.progress(at: t0) == 0)
        engine.play(now: t0)
        #expect(engine.progress(at: at(450)) == 0.25)
        #expect(engine.progress(at: at(9999)) == 1)
        engine.pause(now: at(1350))
        #expect(engine.progress(at: at(9999)) == 0.75)

        let rest = TimerEngine(state: .paused(.rest, remaining: .seconds(60)))
        #expect(rest.progress(at: t0) == 0.8)
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

/// Completes the running or ready phase: Play, then tick at its deadline.
private func complete(_ engine: inout TimerEngine, at now: Date) -> TimerEvent? {
    engine.play(now: now)
    return engine.tick(now: now + engine.remaining(at: now))
}

private let shortSchedule = Schedule(
    focus: .seconds(60), rest: .seconds(10), longRest: .seconds(30), longRestEvery: 2
)

struct CycleTests {
    @Test func longBreakAfterNFocusIntervalsShortRestOtherwise() {
        var engine = TimerEngine(schedule: shortSchedule)
        #expect(complete(&engine, at: t0) == .phaseCompleted(
            PhaseCompletion(phase: .focus, next: .rest, nextDuration: .seconds(10))
        ))
        #expect(engine.state == .ready(.rest))
        _ = complete(&engine, at: at(100))
        #expect(complete(&engine, at: at(200)) == .phaseCompleted(
            PhaseCompletion(phase: .focus, next: .longRest, nextDuration: .seconds(30))
        ))
        #expect(engine.state == .ready(.longRest))
        #expect(engine.remaining(at: at(500)) == .seconds(30))
        #expect(complete(&engine, at: at(300)) == .phaseCompleted(
            PhaseCompletion(phase: .longRest, next: .focus, nextDuration: .seconds(60))
        ))
        // The cycle starts over: the next Focus is followed by Rest.
        _ = complete(&engine, at: at(400))
        #expect(engine.state == .ready(.rest))
    }

    @Test func skippedFocusDoesNotCountTowardsTheLongBreak() {
        var engine = TimerEngine(schedule: shortSchedule)
        _ = complete(&engine, at: t0)
        _ = complete(&engine, at: at(100))
        engine.play(now: at(200))
        engine.skip()
        #expect(engine.state == .ready(.rest))
        engine.skip()
        _ = complete(&engine, at: at(300))
        #expect(engine.state == .ready(.longRest))
    }

    @Test func skipFromALongBreakLoadsFocus() {
        var engine = TimerEngine(schedule: shortSchedule, state: .running(.longRest, endDate: at(30)))
        engine.skip()
        #expect(engine.state == .ready(.focus))
    }

    @Test func resetRestartsTheCycle() {
        var engine = TimerEngine(schedule: shortSchedule)
        _ = complete(&engine, at: t0)
        engine.reset()
        _ = complete(&engine, at: at(100))
        #expect(engine.state == .ready(.rest))
    }

    @Test func longBreakEveryOneFollowsEachFocus() {
        var schedule = shortSchedule
        schedule.longRestEvery = 1
        var engine = TimerEngine(schedule: schedule)
        _ = complete(&engine, at: t0)
        #expect(engine.state == .ready(.longRest))
    }
}

struct ScheduleChangeTests {
    private let longer = Schedule(
        focus: .seconds(50 * 60), rest: .seconds(10 * 60), longRest: .seconds(20 * 60), longRestEvery: 2
    )

    @Test(arguments: [
        (Phase.focus, Duration.seconds(50 * 60)),
        (.rest, .seconds(10 * 60)),
        (.longRest, .seconds(20 * 60)),
    ])
    func readyPhaseTakesTheNewLength(phase: Phase, expected: Duration) {
        var engine = TimerEngine(state: .ready(phase))
        engine.schedule = longer
        #expect(engine.remaining(at: t0) == expected)
        engine.play(now: t0)
        #expect(engine.state == .running(phase, endDate: t0 + expected))
    }

    @Test func runningPhaseGoesBackToReadyWhenItsLengthChanges() {
        var engine = TimerEngine()
        engine.play(now: t0)
        engine.schedule = longer
        #expect(engine.state == .ready(.focus))
        #expect(engine.remaining(at: at(600)) == .seconds(50 * 60))
        #expect(engine.progress(at: at(600)) == 0)
    }

    @Test func pausedPhaseGoesBackToReadyWhenItsLengthChanges() {
        var engine = TimerEngine(state: .paused(.rest, remaining: .seconds(60)))
        engine.schedule = longer
        #expect(engine.state == .ready(.rest))
        #expect(engine.remaining(at: t0) == .seconds(10 * 60))
    }

    @Test func runningPhaseKeepsItsDeadlineWhenAnotherLengthChanges() {
        var engine = TimerEngine()
        engine.play(now: t0)
        var schedule = Schedule.standard
        schedule.rest = .seconds(10 * 60)
        engine.schedule = schedule
        #expect(engine.state == .running(.focus, endDate: at(1800)))
        #expect(engine.progress(at: at(900)) == 0.5)
        // What comes next follows the new schedule.
        #expect(engine.tick(now: at(1800)) == .phaseCompleted(
            PhaseCompletion(phase: .focus, next: .rest, nextDuration: .seconds(10 * 60))
        ))
    }

    @Test func pausedPhaseKeepsItsRemainingTimeWhenAnotherLengthChanges() {
        var engine = TimerEngine()
        engine.play(now: t0)
        engine.pause(now: at(600))
        var schedule = Schedule.standard
        schedule.longRest = .seconds(20 * 60)
        engine.schedule = schedule
        #expect(engine.remaining(at: at(9000)) == .seconds(1200))
        engine.play(now: at(9000))
        #expect(engine.state == .running(.focus, endDate: at(10200)))
    }

    @Test func fewerIntervalsPerCycleGiveALongBreakAtTheNextFocusEnd() {
        var engine = TimerEngine()
        _ = complete(&engine, at: t0)
        _ = complete(&engine, at: at(2000))
        _ = complete(&engine, at: at(3000))
        _ = complete(&engine, at: at(5000))
        engine.schedule = longer
        // Two Focus intervals done already reach the new cycle length.
        _ = complete(&engine, at: at(6000))
        #expect(engine.state == .ready(.longRest))
    }
}

struct PhaseEndOptionsTests {
    @Test func autoStartChainsTheNextPhaseFromThePreviousDeadline() {
        var engine = TimerEngine(schedule: shortSchedule, phaseEnd: PhaseEndOptions(autoStart: true))
        engine.play(now: t0)
        // The tick lands a little late; the next phase still starts at the deadline.
        #expect(engine.tick(now: at(60.4)) == .phaseCompleted(
            PhaseCompletion(phase: .focus, next: .rest, nextDuration: .seconds(10))
        ))
        #expect(engine.state == .running(.rest, endDate: at(70)))
        #expect(engine.tick(now: at(70)) == .phaseCompleted(
            PhaseCompletion(phase: .rest, next: .focus, nextDuration: .seconds(60))
        ))
        #expect(engine.state == .running(.focus, endDate: at(130)))
    }

    /// Short break 10 s, long break 30 s, every second Focus.
    @Test(arguments: [
        (0, 9.9, false),
        (0, 10, true),
        (1, 29.9, false),
        (1, 30, true),
    ])
    func idleForTheComingBreakSkipsIt(focusDone: Int, idleSeconds: Double, skips: Bool) {
        var engine = TimerEngine(schedule: shortSchedule, phaseEnd: PhaseEndOptions(skipBreakIfIdle: true))
        for _ in 0 ..< focusDone {
            _ = complete(&engine, at: t0)
            engine.skip()
        }
        let comingBreak: Phase = focusDone == 1 ? .longRest : .rest
        engine.play(now: t0)
        let event = engine.tick(now: at(60), idleTime: .seconds(idleSeconds))
        if skips {
            #expect(event == .phaseCompleted(PhaseCompletion(
                phase: .focus, next: .focus, nextDuration: .seconds(60), skippedBreak: comingBreak
            )))
            #expect(engine.state == .ready(.focus))
        } else {
            #expect(event == .phaseCompleted(PhaseCompletion(
                phase: .focus, next: comingBreak, nextDuration: engine.schedule.duration(of: comingBreak)
            )))
            #expect(engine.state == .ready(comingBreak))
        }
    }

    @Test func idleDoesNotSkipTheBreakWhenTheOptionIsOff() {
        var engine = TimerEngine(schedule: shortSchedule)
        engine.play(now: t0)
        _ = engine.tick(now: at(60), idleTime: .seconds(3600))
        #expect(engine.state == .ready(.rest))
    }

    @Test func idleSkipWithAutoStartRunsFocusFromTheDeadline() {
        var engine = TimerEngine(
            schedule: shortSchedule, phaseEnd: PhaseEndOptions(autoStart: true, skipBreakIfIdle: true)
        )
        engine.play(now: t0)
        _ = engine.tick(now: at(60.5), idleTime: .seconds(600))
        #expect(engine.state == .running(.focus, endDate: at(120)))
    }
}
