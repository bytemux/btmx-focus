import Intents

/// Whether Do Not Disturb or a macOS Focus mode is on (ADR 0014).
@MainActor
public protocol FocusStatusSource: AnyObject {
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
