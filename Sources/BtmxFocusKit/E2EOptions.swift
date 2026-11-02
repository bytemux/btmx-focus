import BtmxFocusCore
import BtmxFocusUIContract
import Foundation

/// The debug launch arguments the E2E build accepts (ADR 0010). Every other
/// build (another bundle id, or a release build) gets `nil` and ignores them.
public struct E2EOptions: Equatable, Sendable {
    /// Short Focus and Rest lengths that replace the Settings' minutes.
    public var focusLength: Duration?
    public var restLength: Duration?
    public var notificationsEnabled = true
    public var debugLogging = false
    public var resetSettings = false
    public var idleSkipEnabled = true

    /// `nil` unless `bundleIdentifier` is the E2E build's.
    public init?(arguments: [String], bundleIdentifier: String?) {
        guard bundleIdentifier == E2EContract.bundleIdentifier else { return nil }
        let argument = E2EContract.Argument.self
        func seconds(after flag: String) -> Duration? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count,
                  let value = Double(arguments[index + 1]), value > 0 else { return nil }
            return .seconds(value)
        }
        focusLength = seconds(after: argument.focusSeconds)
        restLength = seconds(after: argument.restSeconds)
        notificationsEnabled = !arguments.contains(argument.noNotifications)
        debugLogging = arguments.contains(argument.debugLogging)
        resetSettings = arguments.contains(argument.resetSettings)
        idleSkipEnabled = !arguments.contains(argument.noIdleSkip)
    }

    /// The Settings' schedule with the E2E lengths in place of theirs.
    public func schedule(from preferences: Preferences) -> Schedule {
        var schedule = preferences.schedule
        schedule.focus = focusLength ?? schedule.focus
        schedule.rest = restLength ?? schedule.rest
        return schedule
    }

    /// The Settings' phase-end options, without idle skip if turned off here.
    public func phaseEnd(from preferences: Preferences) -> PhaseEndOptions {
        var options = preferences.phaseEnd
        options.skipBreakIfIdle = options.skipBreakIfIdle && idleSkipEnabled
        return options
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
