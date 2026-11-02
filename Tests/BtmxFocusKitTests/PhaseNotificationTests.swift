import BtmxFocusCore
import BtmxFocusKit
import Testing

struct PhaseNotificationTests {
    @Test(arguments: [
        (
            PhaseCompletion(phase: .focus, next: .rest, nextDuration: .seconds(5 * 60)),
            "Focus done",
            "Time for a 5 min break."
        ),
        (
            PhaseCompletion(phase: .focus, next: .longRest, nextDuration: .seconds(15 * 60)),
            "Focus done",
            "Time for a 15 min long break."
        ),
        (
            PhaseCompletion(phase: .rest, next: .focus, nextDuration: .seconds(50 * 60)),
            "Break over",
            "Ready for 50 min of focus."
        ),
        (
            PhaseCompletion(phase: .longRest, next: .focus, nextDuration: .seconds(25 * 60)),
            "Long break over",
            "Ready for 25 min of focus."
        ),
        (
            PhaseCompletion(phase: .focus, next: .focus, nextDuration: .seconds(30 * 60), skippedBreak: .rest),
            "Focus done",
            "You were away for the break. Ready for 30 min of focus."
        ),
        (
            PhaseCompletion(phase: .focus, next: .focus, nextDuration: .seconds(30 * 60), skippedBreak: .longRest),
            "Focus done",
            "You were away for the long break. Ready for 30 min of focus."
        ),
        // E2E lengths are seconds.
        (
            PhaseCompletion(phase: .focus, next: .rest, nextDuration: .seconds(3)),
            "Focus done",
            "Time for a 3 s break."
        ),
    ])
    func statesTheNextPhaseAndItsLength(completion: PhaseCompletion, title: String, body: String) {
        let notification = PhaseNotification(completion)
        #expect(notification.title == title)
        #expect(notification.body == body)
    }
}
