/// Accessibility identifiers the app sets and the E2E driver looks elements
/// up by. Shared so a rename can't silently break the E2E suite.
public enum AccessibilityID {
    public static let statusItem = "btmx.statusItem"

    public enum Popover {
        public static let root = "btmx.popover"
        public static let phase = "btmx.popover.phase"
        public static let clock = "btmx.popover.clock"
        public static let playPause = "btmx.popover.playPause"
        public static let skip = "btmx.popover.skip"
        public static let reset = "btmx.popover.reset"
        public static let more = "btmx.popover.more"
    }

    /// Items of the popover's `⋯` menu.
    public enum MoreMenu {
        public static let settings = "btmx.more.settings"
        public static let debugLogging = "btmx.more.debugLogging"
        public static let showLogs = "btmx.more.showLogs"
        public static let quit = "btmx.more.quit"
    }

    public enum Settings {
        public static let window = "btmx.settings.window"
        public static let showTimerInMenuBar = "btmx.settings.showTimerInMenuBar"
        public static let launchAtLogin = "btmx.settings.launchAtLogin"
        public static let openLoginItems = "btmx.settings.openLoginItems"
        public static let autoStart = "btmx.settings.autoStart"
        public static let skipBreakIfIdle = "btmx.settings.skipBreakIfIdle"
        public static let focusEndSound = "btmx.settings.focusEndSound"
        public static let breakEndSound = "btmx.settings.breakEndSound"
        public static let volume = "btmx.settings.volume"
        public static let completionNotifications = "btmx.settings.completionNotifications"
        public static let appearance = "btmx.settings.appearance"
    }
}
