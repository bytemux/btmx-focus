import AppKit
import Observation
import ServiceManagement

/// The system login-item service; `SMAppService` in the app, a fake in tests.
public protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Launch at login through the system login-item service for the main app.
/// Not stored (ADR 0008): the status is read from the service and re-read
/// whenever the app becomes active, so it follows System Settings → Login Items.
@MainActor
@Observable
public final class LaunchAtLogin {
    public private(set) var status: SMAppService.Status
    @ObservationIgnored private let service: LoginItemService
    @ObservationIgnored private var activeObserver: NSObjectProtocol?

    public init(service: LoginItemService = SMAppService.mainApp, center: NotificationCenter = .default) {
        self.service = service
        status = service.status
        activeObserver = center.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// On while registered, including while macOS waits for the user's approval.
    public var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    public var requiresApproval: Bool {
        status == .requiresApproval
    }

    public func refresh() {
        status = service.status
    }

    public func setEnabled(_ enabled: Bool) {
        let action = enabled ? "register" : "unregister"
        var failure = ""
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            failure = " failed: \(error.localizedDescription),"
            // The status is unchanged, so observation wouldn't fire on its own;
            // without it the checkbox would keep the user's click.
            withMutation(keyPath: \.status) {}
        }
        refresh()
        CrashLog.record("launch at login: \(action)\(failure) → \(Self.describe(status))")
    }

    public func openLoginItems() {
        CrashLog.record("launch at login: open Login Items")
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: "not registered"
        case .enabled: "enabled"
        case .requiresApproval: "requires approval"
        case .notFound: "not found"
        @unknown default: "unknown (\(status.rawValue))"
        }
    }
}
