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
            case .notificationsAndSounds:
                notificationsAndSounds
            case .intervals:
                EmptyView()
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var notificationsAndSounds: some View {
        endSoundPicker("Work completed sound", after: .focus, identifier: AccessibilityID.Settings.focusEndSound)
        endSoundPicker("End break sound", after: .rest, identifier: AccessibilityID.Settings.breakEndSound)
        Slider(value: $settings.preferences.volume, in: 0 ... 1) {
            Text("Notification sound level")
        } minimumValueLabel: {
            Image(systemName: "speaker.fill")
        } maximumValueLabel: {
            Image(systemName: "speaker.wave.3.fill")
        } onEditingChanged: { editing in
            if !editing {
                settings.volumeSliderReleased()
            }
        }
        .accessibilityIdentifier(AccessibilityID.Settings.volume)
        Toggle("Completion notifications", isOn: $settings.preferences.completionNotifications)
            .accessibilityIdentifier(AccessibilityID.Settings.completionNotifications)
    }

    private func endSoundPicker(_ title: LocalizedStringKey, after phase: Phase, identifier: String) -> some View {
        Picker(title, selection: Binding(
            get: { settings.preferences.endSound(after: phase) ?? "" },
            set: { settings.pickEndSound($0, after: phase) }
        )) {
            Text("None").tag("")
            Divider()
            ForEach(SystemSound.names, id: \.self) { Text($0).tag($0) }
        }
        .accessibilityIdentifier(identifier)
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
