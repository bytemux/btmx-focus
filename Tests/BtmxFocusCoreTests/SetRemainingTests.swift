import BtmxFocusCore
import Foundation
import Testing

private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

struct SetRemainingTests {
    @Test func runningKeepsRunningTowardsTheNewDeadline() {
        var engine = TimerEngine()
        engine.play(now: t0)
        engine.setRemaining(.seconds(15 * 60 + 15), now: t0 + 30)
        #expect(engine.state == .running(.focus, endDate: t0 + 30 + 915))
        // The ring measures against the time set: full again, then empties.
        #expect(engine.progress(at: t0 + 30) == 0)
        #expect(engine.progress(at: t0 + 30 + 915) == 1)
    }

    @Test func readyAndPausedArePausedWithTheNewTime() {
        var ready = TimerEngine()
        ready.setRemaining(.seconds(15), now: t0)
        #expect(ready.state == .paused(.focus, remaining: .seconds(15)))

        var paused = TimerEngine(state: .paused(.rest, remaining: .seconds(100)))
        paused.setRemaining(.seconds(600), now: t0)
        #expect(paused.state == .paused(.rest, remaining: .seconds(600)))
        paused.play(now: t0)
        #expect(paused.state == .running(.rest, endDate: t0 + 600))
    }

    @Test func theSetTimeLastsOnlyForThisPhase() {
        var engine = TimerEngine()
        engine.play(now: t0)
        engine.setRemaining(.seconds(60), now: t0)
        #expect(engine.setLength == .seconds(60))
        _ = engine.tick(now: t0 + 60)
        #expect(engine.state == .ready(.rest))
        #expect(engine.setLength == nil)
        #expect(engine.remaining(at: t0 + 60) == .seconds(300))

        engine.setRemaining(.seconds(60), now: t0)
        engine.reset()
        #expect(engine.setLength == nil)
    }
}
