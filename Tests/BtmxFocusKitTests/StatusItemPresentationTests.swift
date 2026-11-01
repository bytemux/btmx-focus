import AppKit
import BtmxFocusCore
import BtmxFocusKit
import BtmxFocusTestSupport
import Testing

private let t0 = TimerHarness.t0

@MainActor
struct StatusItemPresentationTests {
    @Test func runningShowsTimeFilledSymbolAndPhaseColour() {
        let focus = StatusItemPresentation(
            engine: TimerEngine(state: .running(.focus, endDate: t0 + 1453)), preferences: Preferences(), now: t0
        )
        #expect(focus.text == "24:13")
        #expect(focus.symbolName == "timer.circle.fill")
        #expect(focus.runningColor == .systemRed)
        #expect(focus.accessibilityLabel == "Focus, running, 24 minutes, 13 seconds remaining")

        let rest = StatusItemPresentation(
            engine: TimerEngine(state: .running(.rest, endDate: t0 + 60)), preferences: Preferences(), now: t0
        )
        #expect(rest.symbolName == "cup.and.saucer.fill")
        #expect(rest.runningColor == .systemGreen)
    }

    @Test func timerHiddenWhileRunningShowsIconOnlyButKeepsTheRunningColour() {
        var preferences = Preferences()
        preferences.showTimerInMenuBar = false
        let presentation = StatusItemPresentation(
            engine: TimerEngine(state: .running(.focus, endDate: t0 + 1453)), preferences: preferences, now: t0
        )
        #expect(presentation.text == nil)
        #expect(presentation.symbolName == "timer.circle.fill")
        #expect(presentation.runningColor == .systemRed)
        #expect(presentation.accessibilityLabel == "Focus, running, 24 minutes, 13 seconds remaining")
    }

    @Test func readyShowsOutlineIconOnlyWithoutColour() {
        let focus = StatusItemPresentation(engine: TimerEngine(), preferences: Preferences(), now: t0)
        #expect(focus.text == nil)
        #expect(focus.symbolName == "timer.circle")
        #expect(focus.runningColor == nil)

        let rest = StatusItemPresentation(
            engine: TimerEngine(state: .ready(.rest)), preferences: Preferences(), now: t0
        )
        #expect(rest.symbolName == "cup.and.saucer")
    }

    @Test func pausedShowsFrozenTimeWithPauseSymbolAndNoColour() {
        let presentation = StatusItemPresentation(
            engine: TimerEngine(state: .paused(.rest, remaining: .seconds(65))), preferences: Preferences(), now: t0
        )
        #expect(presentation.text == "01:05")
        #expect(presentation.symbolName == "pause.circle")
        #expect(presentation.runningColor == nil)
    }
}
