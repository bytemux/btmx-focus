import AppKit
import BtmxFocusCore

/// What the menu-bar item shows for a timer at a given moment: the time, the
/// SF Symbol, the running colour and the VoiceOver label.
public struct StatusItemPresentation: Equatable {
    /// `mm:ss`, or `nil` for icon only.
    public let text: String?
    public let symbolName: String
    /// Red while focusing, green while resting; `nil` means the default
    /// template look (follows the menu bar's white/gray).
    public let runningColor: NSColor?
    /// e.g. "Focus, running, 24 minutes, 13 seconds remaining".
    public let accessibilityLabel: String

    public init(engine: TimerEngine, preferences: Preferences, now: Date) {
        let state = engine.state
        let remaining = engine.remaining(at: now)
        // Not started yet: icon only. Hiding the time keeps the icon, which
        // still shows the running colour.
        let isReady = if case .ready = state { true } else { false }
        text = isReady || !preferences.showTimerInMenuBar ? nil : ClockFormat.string(for: remaining)
        symbolName = Self.symbolName(for: state)
        runningColor = Self.runningColor(for: state)
        accessibilityLabel = PhaseStyle.accessibilityLabel(state: state, remaining: remaining)
    }

    /// Ready shows the outline symbol, running the filled one, so a glance
    /// tells whether the clock is moving.
    private static func symbolName(for state: TimerState) -> String {
        switch state {
        case .ready(.focus): "timer.circle"
        case .running(.focus, _): "timer.circle.fill"
        case .ready(.rest), .ready(.longRest): "cup.and.saucer"
        case .running(.rest, _), .running(.longRest, _): "cup.and.saucer.fill"
        case .paused: "pause.circle"
        }
    }

    private static func runningColor(for state: TimerState) -> NSColor? {
        switch state {
        case .running(.focus, _): .systemRed
        case .running(.rest, _), .running(.longRest, _): .systemGreen
        case .ready, .paused: nil
        }
    }
}

@MainActor
public extension StatusItemPresentation {
    var image: NSImage? {
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return nil }
        guard let color = runningColor else {
            image.isTemplate = true
            return image
        }
        let colored = image.withSymbolConfiguration(.init(paletteColors: [color])) ?? image
        colored.isTemplate = false
        return colored
    }

    /// Draws into the status item's button (or any button, for snapshots).
    func apply(to button: NSButton) {
        button.image = image
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        let title = text.map { $0 + " " } ?? ""
        button.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])
        // Icon to the right of the time: status items grow to the left, so the
        // icon stays put when the time appears or disappears.
        button.imagePosition = title.isEmpty ? .imageOnly : .imageTrailing
        button.setAccessibilityLabel(accessibilityLabel)
    }
}
