import AppKit
import BtmxFocusCore
import BtmxFocusKit
import UserNotifications

/// End-of-phase signal: the chosen built-in system sound plus a silent
/// notification, as set in Settings → Notifications & Sounds. The sound is
/// played by the app so it is heard even if notifications are denied.
@MainActor
final class PhaseSignaler: PhaseSignalSink {
    private let notificationDelegate = ForegroundNotificationDelegate()
    private let settings: SettingsStore
    private let soundPlayer: SoundPlayer
    private let notificationsEnabled: Bool
    private var requestedAuthorization = false

    /// `UNUserNotificationCenter` traps outside an app bundle (e.g. `swift run`).
    private var systemNotificationCenter: UNUserNotificationCenter? {
        !notificationsEnabled || Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    /// Nil while Completion notifications is off: nothing is posted and
    /// permission isn't requested (until it is turned on and Play is pressed).
    private var notificationCenter: UNUserNotificationCenter? {
        settings.preferences.completionNotifications ? systemNotificationCenter : nil
    }

    /// `notificationsEnabled: false` (E2E build) means sound only and no permission prompt.
    init(settings: SettingsStore, soundPlayer: SoundPlayer = SystemSoundPlayer(), notificationsEnabled: Bool = true) {
        self.settings = settings
        self.soundPlayer = soundPlayer
        self.notificationsEnabled = notificationsEnabled
        systemNotificationCenter?.delegate = notificationDelegate
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

    func phaseCompleted(_ completion: PhaseCompletion) {
        let preferences = settings.preferences
        let sound = settings.endSoundToPlay(after: completion.phase)
        if let sound {
            soundPlayer.play(sound, volume: preferences.volume)
        }
        postNotification(PhaseNotification(completion))
        CrashLog.record("signal: \(sound ?? "no") sound\(notificationCenter == nil ? "" : " + notification")")
    }

    private func postNotification(_ notification: PhaseNotification) {
        guard let center = notificationCenter else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
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
