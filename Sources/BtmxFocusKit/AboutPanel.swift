import AppKit

/// The standard About panel (name, version, icon). The version is the git
/// commit `scripts/build-app.sh` stamps into Info.plist.
public enum AboutPanel {
    /// Info.plist key holding the build's short commit hash.
    public static let commitKey = "BtmxCommit"

    public static func options(info: [String: Any]) -> [NSApplication.AboutPanelOptionKey: Any] {
        [
            // "dev" under `swift run`, which has no bundle to stamp.
            .applicationVersion: info[commitKey] as? String ?? "dev",
            // Empty hides the "(CFBundleVersion)" after the version.
            .version: "",
        ]
    }

    /// Opens the panel in front. The app has no Dock icon, so it must
    /// activate itself or the panel opens behind other apps.
    @MainActor public static func show() {
        CrashLog.record("about open")
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: options(info: Bundle.main.infoDictionary ?? [:]))
    }
}
