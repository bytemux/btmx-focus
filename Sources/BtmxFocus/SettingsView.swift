import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                Form {
                    Toggle("Show timer in menu bar", isOn: $settings.preferences.showTimerInMenuBar)
                }
            }
            Tab("Intervals", systemImage: "timer") {
                Form {}
            }
            Tab("Notifications & Sounds", systemImage: "bell.badge") {
                Form {}
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 300)
    }
}
