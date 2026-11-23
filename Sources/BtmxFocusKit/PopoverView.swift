import AppKit
import BtmxFocusCore
import BtmxFocusUIContract
import SwiftUI

public struct PopoverView: View {
    let model: TimerModel
    /// Settings → Intervals → Target per day, for the daily dots.
    let dailyTarget: Int
    let openSettings: () -> Void
    /// Esc: closes the popover and hands the keyboard back.
    let close: () -> Void
    @AppStorage(CrashLog.debugLoggingKey) private var debugLogging = false
    /// While the clock is being edited: the time it froze at and what has
    /// been typed so far. The timer itself keeps running.
    @State private var edit: ClockEdit?

    struct ClockEdit: Equatable {
        var frozen: String
        var typed = ""
    }

    public init(
        model: TimerModel, dailyTarget: Int, openSettings: @escaping () -> Void, close: @escaping () -> Void = {}
    ) {
        self.model = model
        self.dailyTarget = dailyTarget
        self.openSettings = openSettings
        self.close = close
    }

    /// The phase colour (red Focus, green Rest), gray while Paused.
    private var ringColor: Color {
        switch model.state {
        case .paused: .secondary
        case .ready(.focus), .running(.focus, _): .red
        case .ready(.rest), .running(.rest, _), .ready(.longRest), .running(.longRest, _): .green
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

                clock

                Button {
                    commitEdit()
                    model.togglePlayPause()
                } label: {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .frame(width: 56, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Return sets the typed time while editing, not Play.
                .keyboardShortcut(edit == nil ? .defaultAction : nil)
                .accessibilityLabel(model.isRunning ? Text("Pause") : Text("Play"))
                .accessibilityIdentifier(AccessibilityID.Popover.playPause)
            }
            .frame(width: 200, height: 200)
            .background(ProgressRing(progress: model.progress, color: ringColor))

            DailyDots(count: model.todayCount, target: dailyTarget, focusedTime: model.todayFocusedTime)
                .accessibilityIdentifier(AccessibilityID.Popover.today)

            Divider()

            HStack {
                Button {
                    commitEdit()
                    model.skip()
                } label: {
                    Label(skipName, systemImage: "forward.end.fill")
                }
                .help(skipName)
                .accessibilityIdentifier(AccessibilityID.Popover.skip)

                Button {
                    commitEdit()
                    model.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(!model.canReset)
                .help("Reset")
                .accessibilityIdentifier(AccessibilityID.Popover.reset)

                Divider()
                    .frame(height: 14)

                Button {
                    commitEdit()
                    model.resetToday()
                } label: {
                    Label("Reset Today's Progress", systemImage: "calendar.badge.minus")
                }
                .disabled(!model.canResetToday)
                .help("Reset Today's Progress")
                .accessibilityIdentifier(AccessibilityID.Popover.resetToday)

                Spacer()

                Menu {
                    Button("About btmx-focus") { AboutPanel.show() }
                        .accessibilityIdentifier(AccessibilityID.MoreMenu.about)
                    Divider()
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
                .help("More")
                .accessibilityLabel(Text("More"))
                .accessibilityIdentifier(AccessibilityID.Popover.more)
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
        }
        .padding(16)
        .frame(width: 240)
        // A click anywhere else in the popover sets the typed time.
        .contentShape(Rectangle())
        .onTapGesture { commitEdit() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Popover.root)
        .focusable()
        .focusEffectDisabled()
        .onChange(of: debugLogging) { _, enabled in
            CrashLog.setDebugLogging(enabled)
            CrashLog.record("debug logging \(enabled ? "on" : "off")")
        }
        .onKeyPress(.space) {
            // While editing a space separates, as in "15 30" or "1h 30m".
            guard edit == nil else { return type(" ") }
            model.togglePlayPause()
            return .handled
        }
        .onKeyPress(.escape) {
            // Esc while editing keeps the time as it was.
            if edit != nil {
                edit = nil
            } else {
                close()
            }
            return .handled
        }
        .onKeyPress(.return) {
            guard edit != nil else { return .ignored }
            commitEdit()
            return .handled
        }
        .onKeyPress(.delete) {
            guard edit != nil else { return .ignored }
            edit?.typed = String(edit?.typed.dropLast() ?? "")
            return .handled
        }
        // Digits, separators and unit letters ("25m", "1ч 15м"); see ClockEntry.
        .onKeyPress(characters: CharacterSet(charactersIn: ":.,").union(.decimalDigits).union(.letters)) { press in
            edit == nil ? .ignored : type(press.characters)
        }
        // Closing the popover is clicking away too.
        .onDisappear { commitEdit() }
    }

    /// "Skip to Rest", "Skip to Focus": the Skip button's name and tooltip.
    private var skipName: String {
        String(localized: "Skip to \(PhaseStyle.name(of: model.state.phase.next))")
    }

    /// The clock, a button: a click freezes the shown time and lets the user
    /// type a new one (`ClockEntry`); Return or a click elsewhere sets it.
    private var clock: some View {
        Button {
            if edit == nil {
                edit = ClockEdit(frozen: model.clockText)
            } else {
                commitEdit()
            }
        } label: {
            Text(clockShown)
                .font(.system(size: 38, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(edit == nil ? .primary : Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: 140)
                .padding(.horizontal, 6)
                .background {
                    if edit != nil {
                        RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.12))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to type a new time")
        .accessibilityLabel(PhaseStyle.accessibilityLabel(state: model.state, remaining: model.remaining))
        .accessibilityHint(Text("Type a new time, then press Return"))
        .accessibilityIdentifier(AccessibilityID.Popover.clock)
    }

    /// The live time; while editing the frozen time, then the typed time as
    /// it will be set ("15" shows 00:15), or the raw text if it isn't one yet.
    private var clockShown: String {
        guard let edit else { return model.clockText }
        guard !edit.typed.isEmpty else { return edit.frozen }
        return ClockEntry.duration(from: edit.typed).map { ClockFormat.string(for: $0) } ?? edit.typed
    }

    /// Adds `text` to the time being typed, up to `ClockEntry.maxLength`.
    private func type(_ text: String) -> KeyPress.Result {
        if let typed = edit?.typed, typed.count < ClockEntry.maxLength {
            edit?.typed = typed + text
        }
        return .handled
    }

    /// Sets the typed time, if it is one, and stops editing.
    private func commitEdit() {
        guard let current = edit else { return }
        edit = nil
        if let duration = ClockEntry.duration(from: current.typed) {
            model.setRemaining(duration)
        }
    }
}
