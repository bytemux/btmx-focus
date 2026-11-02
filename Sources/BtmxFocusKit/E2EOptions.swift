import BtmxFocusCore
import BtmxFocusUIContract
import Foundation

/// The debug launch arguments the E2E build accepts (ADR 0010). Every other
/// build (another bundle id, or a release build) gets `nil` and ignores them.
public struct E2EOptions: Equatable, Sendable {
    public var schedule = Schedule.standard
    public var notificationsEnabled = true
    public var debugLogging = false
    public var resetSettings = false

    /// `nil` unless `bundleIdentifier` is the E2E build's.
    public init?(arguments: [String], bundleIdentifier: String?) {
        guard bundleIdentifier == E2EContract.bundleIdentifier else { return nil }
        let argument = E2EContract.Argument.self
        func seconds(after flag: String) -> Duration? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count,
                  let value = Double(arguments[index + 1]), value > 0 else { return nil }
            return .seconds(value)
        }
        schedule = Schedule(
            focus: seconds(after: argument.focusSeconds) ?? Schedule.standard.focus,
            rest: seconds(after: argument.restSeconds) ?? Schedule.standard.rest
        )
        notificationsEnabled = !arguments.contains(argument.noNotifications)
        debugLogging = arguments.contains(argument.debugLogging)
        resetSettings = arguments.contains(argument.resetSettings)
    }

    /// This process's options. Always `nil` in release builds.
    public static var current: E2EOptions? {
        #if DEBUG
            E2EOptions(arguments: CommandLine.arguments, bundleIdentifier: Bundle.main.bundleIdentifier)
        #else
            nil
        #endif
    }
}
