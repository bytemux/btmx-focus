import BtmxFocusCore
import BtmxFocusKit
import BtmxFocusUIContract
import Testing

struct E2EOptionsTests {
    @Test func ignoredOutsideTheE2EBuild() {
        let arguments = ["app", E2EContract.Argument.focusSeconds, "3", E2EContract.Argument.noNotifications]
        #expect(E2EOptions(arguments: arguments, bundleIdentifier: "com.btmx.focus") == nil)
        #expect(E2EOptions(arguments: arguments, bundleIdentifier: nil) == nil)
    }

    @Test func defaultsWithoutArguments() throws {
        let options = try #require(E2EOptions(arguments: ["app"], bundleIdentifier: E2EContract.bundleIdentifier))
        #expect(options.schedule(from: Preferences()) == .standard)
        #expect(options.notificationsEnabled)
        #expect(!options.debugLogging)
        #expect(!options.resetSettings)
        #expect(options.phaseEnd(from: Preferences()) == Preferences().phaseEnd)
    }

    @Test func readsEveryArgument() throws {
        let arguments = [
            "app",
            E2EContract.Argument.focusSeconds, "3",
            E2EContract.Argument.restSeconds, "2",
            E2EContract.Argument.noNotifications,
            E2EContract.Argument.debugLogging,
            E2EContract.Argument.resetSettings,
            E2EContract.Argument.noIdleSkip,
        ]
        let options = try #require(E2EOptions(arguments: arguments, bundleIdentifier: E2EContract.bundleIdentifier))
        #expect(options.schedule(from: Preferences()) == Schedule(
            focus: .seconds(3), rest: .seconds(2), longRest: .seconds(15 * 60), longRestEvery: 4
        ))
        #expect(!options.notificationsEnabled)
        #expect(options.debugLogging)
        #expect(options.resetSettings)
        var preferences = Preferences()
        preferences.autoStart = true
        #expect(options.phaseEnd(from: preferences) == PhaseEndOptions(autoStart: true, skipBreakIfIdle: false))
    }

    /// The seconds win over the Settings' minutes; the rest follows Settings.
    @Test func secondsOverrideTheSettingsLengths() throws {
        let arguments = ["app", E2EContract.Argument.focusSeconds, "3"]
        let options = try #require(E2EOptions(arguments: arguments, bundleIdentifier: E2EContract.bundleIdentifier))
        var preferences = Preferences()
        preferences.focusMinutes = 50
        preferences.shortRestMinutes = 10
        preferences.longRestEvery = 2
        #expect(options.schedule(from: preferences) == Schedule(
            focus: .seconds(3), rest: .seconds(600), longRest: .seconds(15 * 60), longRestEvery: 2
        ))
    }

    @Test func badSecondsKeepTheSettingsLength() throws {
        let arguments = ["app", E2EContract.Argument.focusSeconds, "soon", E2EContract.Argument.restSeconds]
        let options = try #require(E2EOptions(arguments: arguments, bundleIdentifier: E2EContract.bundleIdentifier))
        #expect(options.schedule(from: Preferences()) == .standard)
    }
}
