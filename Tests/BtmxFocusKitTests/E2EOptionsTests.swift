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
        #expect(options.schedule == .standard)
        #expect(options.notificationsEnabled)
        #expect(!options.debugLogging)
        #expect(!options.resetSettings)
    }

    @Test func readsEveryArgument() throws {
        let arguments = [
            "app",
            E2EContract.Argument.focusSeconds, "3",
            E2EContract.Argument.restSeconds, "2",
            E2EContract.Argument.noNotifications,
            E2EContract.Argument.debugLogging,
            E2EContract.Argument.resetSettings,
        ]
        let options = try #require(E2EOptions(arguments: arguments, bundleIdentifier: E2EContract.bundleIdentifier))
        #expect(options.schedule == Schedule(focus: .seconds(3), rest: .seconds(2)))
        #expect(!options.notificationsEnabled)
        #expect(options.debugLogging)
        #expect(options.resetSettings)
    }

    @Test func badSecondsKeepTheStandardLength() throws {
        let arguments = ["app", E2EContract.Argument.focusSeconds, "soon", E2EContract.Argument.restSeconds]
        let options = try #require(E2EOptions(arguments: arguments, bundleIdentifier: E2EContract.bundleIdentifier))
        #expect(options.schedule == .standard)
    }
}
