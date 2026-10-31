import AppKit
import BtmxFocusCore
import UserNotifications

/// End-of-phase signal: a built-in system sound plus a silent notification.
/// The sound is played by the app so it is heard even if notifications are denied.
@MainActor
final class PhaseSignaler {
    private let notificationDelegate = ForegroundNotificationDelegate()
    private var requestedAuthorization = false

    /// `UNUserNotificationCenter` traps outside an app bundle (e.g. `swift run`).
    private var notificationCenter: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    init() {
        notificationCenter?.delegate = notificationDelegate
    }

    func requestAuthorizationIfNeeded() {
        guard !requestedAuthorization, let center = notificationCenter else { return }
        requestedAuthorization = true
        // Async API on purpose: a completion-handler closure formed here would be
        // main-actor isolated, and UserNotifications calls it on a background queue,
        // which traps under Swift 6 runtime isolation checks.
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert])
                CrashLog.record("notifications authorization: \(granted ? "granted" : "denied")")
            } catch {
                CrashLog.record("notifications authorization failed: \(error.localizedDescription)")
            }
        }
    }

    func phaseCompleted(_ phase: Phase) {
        NSSound(named: soundName(after: phase))?.play()
        postNotification(after: phase)
    }

    private func soundName(after phase: Phase) -> NSSound.Name {
        switch phase {
        case .focus: "Glass"
        case .rest: "Hero"
        }
    }

    private func postNotification(after phase: Phase) {
        guard let center = notificationCenter else { return }
        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = String(localized: "Focus done")
            content.body = String(localized: "Time for a 5 min break.")
        case .rest:
            content.title = String(localized: "Break over")
            content.body = String(localized: "Ready for 30 min of focus.")
        }
        let request = UNNotificationRequest(identifier: "phase-end", content: content, trigger: nil)
        center.add(request)
    }
}

/// Shows banners even while the popover makes the app active.
private final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
