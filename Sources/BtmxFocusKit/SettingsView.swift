import BtmxFocusCore
import BtmxFocusUIContract
import SwiftUI

public enum SettingsTab: CaseIterable, Sendable {
    case general
    case intervals
    case notificationsAndSounds
}

public struct SettingsView: View {
    @Bindable var settings: SettingsStore
    let launchAtLogin: LaunchAtLogin

    public init(settings: SettingsStore, launchAtLogin: LaunchAtLogin) {
        self.settings = settings
        self.launchAtLogin = launchAtLogin
    }

    public var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                SettingsTabContent(tab: .general, settings: settings, launchAtLogin: launchAtLogin)
            }
            Tab("Intervals", systemImage: "timer") {
                SettingsTabContent(tab: .intervals, settings: settings, launchAtLogin: launchAtLogin)
            }
            Tab("Notifications & Sounds", systemImage: "bell.badge") {
                SettingsTabContent(tab: .notificationsAndSounds, settings: settings, launchAtLogin: launchAtLogin)
            }
        }
        .frame(width: 460, height: 300)
    }
}

/// The form inside one Settings tab, without the tab bar around it.
public struct SettingsTabContent: View {
    let tab: SettingsTab
    @Bindable var settings: SettingsStore
    let launchAtLogin: LaunchAtLogin

    public init(tab: SettingsTab, settings: SettingsStore, launchAtLogin: LaunchAtLogin) {
        self.tab = tab
        self.settings = settings
        self.launchAtLogin = launchAtLogin
    }

    public var body: some View {
        Form {
            switch tab {
            case .general:
                Toggle("Show timer in menu bar", isOn: $settings.preferences.showTimerInMenuBar)
                    .accessibilityIdentifier(AccessibilityID.Settings.showTimerInMenuBar)
                launchAtLoginToggle
                Picker("Appearance", selection: $settings.preferences.appearance) {
                    Text("Auto").tag(Appearance.auto)
                    Text("Light").tag(Appearance.light)
                    Text("Dark").tag(Appearance.dark)
                }
                .accessibilityIdentifier(AccessibilityID.Settings.appearance)
            case .intervals, .notificationsAndSounds:
                EmptyView()
            }
        }
        .formStyle(.grouped)
    }

    private var launchAtLoginToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at startup", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            .accessibilityIdentifier(AccessibilityID.Settings.launchAtLogin)
            if launchAtLogin.requiresApproval {
                HStack {
                    Text("Allow btmx-focus in System Settings to open it at login.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Login Items") { launchAtLogin.openLoginItems() }
                        .accessibilityIdentifier(AccessibilityID.Settings.openLoginItems)
                }
            }
        }
    }
}
