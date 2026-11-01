import AppKit
import BtmxFocusCore
import Observation
import SwiftUI

/// Menu-bar item (icon + monospaced `mm:ss`) that toggles the popover.
@MainActor
final class StatusItemController: NSObject {
    private let model: TimerModel
    private let settings: SettingsStore
    private let settingsWindow: SettingsWindowController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    /// Invisible, fixed window over the icon that the open popover hangs from.
    /// The status item resizes and moves while the popover is open (the time
    /// appears or disappears), and NSPopover re-anchors to the item's stale
    /// position; anchoring to a window that never moves keeps the popover still.
    private let anchorWindow = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
    private var lastClose = Date.distantPast

    init(model: TimerModel, settings: SettingsStore, settingsWindow: SettingsWindowController) {
        self.model = model
        self.settings = settings
        self.settingsWindow = settingsWindow
        super.init()

        popover.behavior = .transient
        popover.delegate = self

        anchorWindow.isOpaque = false
        anchorWindow.backgroundColor = .clear
        anchorWindow.ignoresMouseEvents = true
        anchorWindow.level = .statusBar
        anchorWindow.isReleasedWhenClosed = false
        anchorWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
        }
        render()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // A click on the item while open first closes the transient popover;
        // don't reopen it on the same click.
        guard Date().timeIntervalSince(lastClose) > 0.3, let iconFrame = iconScreenFrame(),
              let anchor = anchorWindow.contentView else { return }
        CrashLog.record("popover open")
        anchorWindow.setFrame(iconFrame, display: false)
        anchorWindow.orderFront(nil)
        // Content exists only while shown, so a closed popover never redraws.
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: model, openSettings: { [weak self] in self?.openSettings() })
        )
        NSApp.activate()
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func openSettings() {
        popover.performClose(nil)
        settingsWindow.show()
    }

    /// The icon's frame in screen coordinates; it sits at the item's trailing edge.
    private func iconScreenFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let rect = button.cell?.imageRect(forBounds: button.bounds) ?? button.bounds
        return window.convertToScreen(button.convert(rect, to: nil))
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
        // Hiding the time keeps the icon, which still shows the running colour.
        let text = settings.preferences.showTimerInMenuBar ? model.menuBarText : nil
        let title = text.map { $0 + " " } ?? ""
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

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_: Notification) {
        CrashLog.record("popover close")
        lastClose = Date()
        anchorWindow.orderOut(nil)
        popover.contentViewController = nil
    }
}
