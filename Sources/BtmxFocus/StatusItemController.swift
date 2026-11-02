import AppKit
import BtmxFocusKit
import BtmxFocusUIContract
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
            button.setAccessibilityIdentifier(AccessibilityID.statusItem)
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
            rootView: PopoverView(
                model: model,
                openSettings: { [weak self] in self?.openSettings() },
                close: { [weak self] in self?.popover.performClose(nil) }
            )
        )
        // The plain NSApp.activate() is only a request, and macOS 27 turns it
        // down for a status-item click: the popover would open without keyboard
        // focus (no Space, no Esc) and wouldn't close on clicks elsewhere.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Settings first, so the popover's close doesn't hand the keyboard away.
    private func openSettings() {
        settingsWindow.show()
        popover.performClose(nil)
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
        StatusItemPresentation(engine: model.engine, preferences: settings.preferences, now: model.now)
            .apply(to: button)
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_: Notification) {
        CrashLog.record("popover close")
        lastClose = Date()
        anchorWindow.orderOut(nil)
        popover.contentViewController = nil
        // Give the keyboard back to the app the user came from, unless they
        // went on to Settings.
        if !settingsWindow.isVisible {
            NSApp.hide(nil)
        }
    }
}
