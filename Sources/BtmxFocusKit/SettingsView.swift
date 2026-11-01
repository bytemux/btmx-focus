import SwiftUI

public enum SettingsTab: CaseIterable, Sendable {
    case general
    case intervals
    case notificationsAndSounds
}

public struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @State private var selectedTab: SettingsTab

    public init(settings: SettingsStore, selectedTab: SettingsTab = .general) {
        self.settings = settings
        _selectedTab = State(initialValue: selectedTab)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab("General", systemImage: "gearshape", value: .general) {
                Form {
                    Toggle("Show timer in menu bar", isOn: $settings.preferences.showTimerInMenuBar)
                }
            }
            Tab("Intervals", systemImage: "timer", value: .intervals) {
                Form {}
            }
            Tab("Notifications & Sounds", systemImage: "bell.badge", value: .notificationsAndSounds) {
                Form {}
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 300)
    }
}
