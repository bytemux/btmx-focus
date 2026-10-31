import AppKit
import BtmxFocusCore
import SwiftUI

struct PopoverView: View {
    let model: TimerModel
    @AppStorage(CrashLog.debugLoggingKey) private var debugLogging = false

    var body: some View {
        VStack(spacing: 12) {
            Text(PhaseStyle.name(of: model.state.phase))
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(model.clockText)
                .font(.system(size: 56, weight: .light, design: .rounded).monospacedDigit())
                .accessibilityLabel(PhaseStyle.accessibilityLabel(state: model.state, remaining: model.remaining))

            Button(action: model.togglePlayPause) {
                Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .frame(width: 56, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel(model.isRunning ? Text("Pause") : Text("Play"))

            Divider()

            HStack {
                Button {
                    model.skip()
                } label: {
                    Label("Skip to \(PhaseStyle.name(of: model.state.phase.next))", systemImage: "forward.end.fill")
                }

                Button {
                    model.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(model.state == .ready(.focus))

                Spacer()

                Menu {
                    Toggle("Debug Logging", isOn: $debugLogging)
                    Button("Show Logs in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([CrashLog.directory])
                    }
                    Divider()
                    Button("Quit btmx-focus") { NSApp.terminate(nil) }
                        .keyboardShortcut("q")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel(Text("More"))
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .help("Skip, reset or quit")
        }
        .padding(16)
        .frame(width: 240)
        .focusable()
        .focusEffectDisabled()
        .onChange(of: debugLogging) { _, enabled in
            CrashLog.setDebugLogging(enabled)
            CrashLog.record("debug logging \(enabled ? "on" : "off")")
        }
        .onKeyPress(.space) {
            model.togglePlayPause()
            return .handled
        }
    }
}
