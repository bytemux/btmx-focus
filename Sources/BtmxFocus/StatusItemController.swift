import AppKit
import BtmxFocusCore
import Observation
import SwiftUI

/// Menu-bar item (icon + monospaced `mm:ss`) that toggles the popover.
@MainActor
final class StatusItemController: NSObject {
    private let model: TimerModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    init(model: TimerModel) {
        self.model = model
        super.init()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView(model: model))

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
        }
        render()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            CrashLog.record("popover close")
            popover.performClose(nil)
        } else {
            CrashLog.record("popover open")
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Redraws the button and re-arms observation for the next model change.
    private func render() {
        withObservationTracking {
            draw()
        } onChange: { [weak self] in
            Task { @MainActor in self?.render() }
        }
    }

    private func draw() {
        guard let button = statusItem.button else { return }
        let state = model.state
        button.image = statusImage(for: state)

        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        let title = model.menuBarText.map { $0 + " " } ?? ""
        button.attributedTitle = NSAttributedString(string: title, attributes: [.font: font])
        // Icon to the right of the time: status items grow to the left, so the
        // icon stays put when the time appears or disappears.
        button.imagePosition = title.isEmpty ? .imageOnly : .imageTrailing
        button.setAccessibilityLabel(PhaseStyle.accessibilityLabel(state: state, remaining: model.remaining))
    }

    /// Red while focusing, green while resting; a template image (follows the
    /// menu bar's white/gray) when the timer isn't running.
    private func statusImage(for state: TimerState) -> NSImage? {
        guard let image = NSImage(systemSymbolName: PhaseStyle.statusSymbol(for: state), accessibilityDescription: nil)
        else { return nil }
        guard let color = PhaseStyle.runningColor(for: state) else {
            image.isTemplate = true
            return image
        }
        let colored = image.withSymbolConfiguration(.init(paletteColors: [color])) ?? image
        colored.isTemplate = false
        return colored
    }
}
