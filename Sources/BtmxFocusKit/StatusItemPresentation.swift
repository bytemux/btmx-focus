import AppKit
import BtmxFocusCore

/// What the menu-bar item shows for a timer at a given moment: the time, the
/// icon (the logo, an SF Symbol, or the progress ring while Running), the
/// running colour and the VoiceOver label.
public struct StatusItemPresentation: Equatable {
    public enum Icon: Equatable {
        /// The app icon's ring and ƒ (`MenuBarLogo`).
        case logo
        case symbol(String)
    }

    /// `mm:ss`, or `nil` for icon only.
    public let text: String?
    public let icon: Icon
    /// Red while focusing, green while resting; `nil` means the default
    /// template look (follows the menu bar's white/gray).
    public let runningColor: NSColor?
    /// Elapsed fraction of the phase while Running, drawn as a progress ring
    /// in place of the symbol; `nil` otherwise.
    public let ringProgress: Double?
    /// e.g. "Focus, running, 24 minutes, 13 seconds remaining".
    public let accessibilityLabel: String

    public init(engine: TimerEngine, preferences: Preferences, now: Date) {
        let state = engine.state
        let remaining = engine.remaining(at: now)
        // Not started yet: icon only. Hiding the time keeps the icon, which
        // still shows the running colour.
        let isReady = if case .ready = state { true } else { false }
        text = isReady || !preferences.showTimerInMenuBar ? nil : ClockFormat.string(for: remaining)
        icon = Self.icon(for: state)
        runningColor = Self.runningColor(for: state)
        ringProgress = if case .running = state { engine.progress(at: now) } else { nil }
        accessibilityLabel = PhaseStyle.accessibilityLabel(state: state, remaining: remaining)
    }

    /// Ready shows the logo or the outline symbol, running the filled one, so
    /// a glance tells whether the clock is moving.
    private static func icon(for state: TimerState) -> Icon {
        switch state {
        case .ready(.focus): .logo
        case .running(.focus, _): .symbol("timer.circle.fill")
        case .ready(.rest), .ready(.longRest): .symbol("cup.and.saucer")
        case .running(.rest, _), .running(.longRest, _): .symbol("cup.and.saucer.fill")
        case .paused: .symbol("pause.circle")
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
        if let ringProgress, let runningColor {
            return ProgressRing.menuBarImage(progress: ringProgress, color: runningColor)
        }
        let symbolName: String
        switch icon {
        case .logo: return MenuBarLogo.image
        case let .symbol(name): symbolName = name
        }
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
