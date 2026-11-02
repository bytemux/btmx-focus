/// How the E2E driver talks to the E2E build of the app
/// (`scripts/build-app.sh e2e`, ADR 0010). Any other build ignores all of this.
public enum E2EContract {
    public static let bundleIdentifier = "com.btmx.focus.e2e"
    public static let appName = "btmx-focus E2E"

    /// Posted on the distributed notification center; the app reacts as if
    /// the Mac were going to sleep.
    public static let simulateSleepNotification = "com.btmx.focus.e2e.simulateSleep"

    /// Debug launch arguments.
    public enum Argument {
        /// Followed by a number of seconds.
        public static let focusSeconds = "--e2e-focus-seconds"
        /// Followed by a number of seconds.
        public static let restSeconds = "--e2e-rest-seconds"
        /// No notifications and so no permission prompt; the sound still plays.
        public static let noNotifications = "--e2e-no-notifications"
        /// Debug logging on from launch (`breadcrumbs.log`).
        public static let debugLogging = "--e2e-debug-logging"
        /// Wipes all settings before anything reads them.
        public static let resetSettings = "--e2e-reset-settings"
    }
}
