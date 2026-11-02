import Intents
import Security

/// Whether Do Not Disturb or a macOS Focus mode is on (ADR 0014).
@MainActor
public protocol FocusStatusSource: AnyObject {
    /// Whether this build can read the Focus status at all (it has the
    /// entitlement), whether or not the user has granted access yet.
    var isAvailable: Bool { get }
    /// Nil when the status can't be read (no permission or entitlement).
    var isFocusActive: Bool? { get }
    /// Asks the user, once, to let the app read the Focus status.
    func requestAccess()
}

/// The Focus status from `INFocusStatusCenter`. Reading it needs the user's
/// permission and the Communication Notifications entitlement; without
/// either, `isFocusActive` is nil.
@MainActor
public final class SystemFocusStatus: FocusStatusSource {
    public let isAvailable = hasEntitlement("com.apple.developer.usernotifications.communication")

    public init() {}

    public var isFocusActive: Bool? {
        let center = INFocusStatusCenter.default
        guard center.authorizationStatus == .authorized else { return nil }
        return center.focusStatus.isFocused
    }

    public func requestAccess() {
        guard INFocusStatusCenter.default.authorizationStatus == .notDetermined else { return }
        // Async API on purpose: the completion handler runs on a background
        // queue, which traps for a main-actor closure under Swift 6.
        Task.detached {
            let status = await INFocusStatusCenter.default.requestAuthorization()
            await CrashLog.record("focus status authorization: \(status.rawValue)")
        }
    }
}

/// Whether the running process's code signature grants `entitlement` (a
/// Boolean entitlement set to true).
private func hasEntitlement(_ entitlement: String) -> Bool {
    guard let task = SecTaskCreateFromSelf(nil) else { return false }
    let value = SecTaskCopyValueForEntitlement(task, entitlement as CFString, nil)
    return value as? Bool == true
}
