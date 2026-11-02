import BtmxFocusUIContract
import SwiftUI

public enum SettingsTab: CaseIterable, Sendable {
    case general
    case intervals
    case notificationsAndSounds
}

public struct SettingsView: View {
    @Bindable var settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                SettingsTabContent(tab: .general, settings: settings)
            }
            Tab("Intervals", systemImage: "timer") {
                SettingsTabContent(tab: .intervals, settings: settings)
            }
            Tab("Notifications & Sounds", systemImage: "bell.badge") {
                SettingsTabContent(tab: .notificationsAndSounds, settings: settings)
            }
        }
        .frame(width: 460, height: 300)
    }
}

/// The form inside one Settings tab, without the tab bar around it.
public struct SettingsTabContent: View {
    let tab: SettingsTab
    @Bindable var settings: SettingsStore

    public init(tab: SettingsTab, settings: SettingsStore) {
        self.tab = tab
        self.settings = settings
    }

    public var body: some View {
        Form {
            switch tab {
            case .general:
                Toggle("Show timer in menu bar", isOn: $settings.preferences.showTimerInMenuBar)
                    .accessibilityIdentifier(AccessibilityID.Settings.showTimerInMenuBar)
            case .intervals, .notificationsAndSounds:
                EmptyView()
            }
        }
        .formStyle(.grouped)
    }
}
