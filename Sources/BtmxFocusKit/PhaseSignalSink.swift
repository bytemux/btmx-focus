import BtmxFocusCore

/// Where the end of a phase is announced (sound + notification in the app).
@MainActor
public protocol PhaseSignalSink: AnyObject {
    /// Called on Play, before anything needs to be announced.
    func requestAuthorizationIfNeeded()
    func phaseCompleted(_ phase: Phase)
}
