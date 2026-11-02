import AppKit
import BtmxFocusCore
import BtmxFocusUIContract
import SwiftUI

public struct PopoverView: View {
    let model: TimerModel
    let openSettings: () -> Void
    /// Esc: closes the popover and hands the keyboard back.
    let close: () -> Void
    @AppStorage(CrashLog.debugLoggingKey) private var debugLogging = false

    public init(model: TimerModel, openSettings: @escaping () -> Void, close: @escaping () -> Void = {}) {
        self.model = model
        self.openSettings = openSettings
        self.close = close
    }

    /// The phase colour (red Focus, green Rest), gray while Paused.
    private var ringColor: Color {
        switch model.state {
        case .paused: .secondary
        case .ready(.focus), .running(.focus, _): .red
        case .ready(.rest), .running(.rest, _): .green
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            // The phase name, clock and Play/Pause sit together inside the ring.
            VStack(spacing: 0) {
                Text(PhaseStyle.name(of: model.state.phase))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.Popover.phase)

                Text(model.clockText)
                    .font(.system(size: 38, weight: .light, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: 140)
                    .accessibilityLabel(
                        PhaseStyle.accessibilityLabel(state: model.state, remaining: model.remaining)
                    )
                    .accessibilityIdentifier(AccessibilityID.Popover.clock)

                Button(action: model.togglePlayPause) {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .frame(width: 56, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(model.isRunning ? Text("Pause") : Text("Play"))
                .accessibilityIdentifier(AccessibilityID.Popover.playPause)
            }
            .frame(width: 200, height: 200)
            .background(ProgressRing(progress: model.progress, color: ringColor))

            Divider()

            HStack {
                Button {
                    model.skip()
                } label: {
                    Label("Skip to \(PhaseStyle.name(of: model.state.phase.next))", systemImage: "forward.end.fill")
                }
                .accessibilityIdentifier(AccessibilityID.Popover.skip)

                Button {
                    model.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(!model.canReset)
                .accessibilityIdentifier(AccessibilityID.Popover.reset)

                Spacer()

                Menu {
                    Button("Settings…", action: openSettings)
                        .keyboardShortcut(",")
                        .accessibilityIdentifier(AccessibilityID.MoreMenu.settings)
                    Divider()
                    Toggle("Debug Logging", isOn: $debugLogging)
                        .accessibilityIdentifier(AccessibilityID.MoreMenu.debugLogging)
                    Button("Show Logs in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([CrashLog.directory])
                    }
                    .accessibilityIdentifier(AccessibilityID.MoreMenu.showLogs)
                    Divider()
                    Button("Quit btmx-focus") { NSApp.terminate(nil) }
                        .keyboardShortcut("q")
                        .accessibilityIdentifier(AccessibilityID.MoreMenu.quit)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel(Text("More"))
                .accessibilityIdentifier(AccessibilityID.Popover.more)
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .help("Skip, reset, settings or quit")
        }
        .padding(16)
        .frame(width: 240)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Popover.root)
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
        .onKeyPress(.escape) {
            close()
            return .handled
        }
    }
}
