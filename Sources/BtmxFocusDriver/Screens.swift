import AppKit
import ApplicationServices
import CoreGraphics

/// Whether a click at an element would reach it: on a display, and for the
/// menu bar not hidden behind the camera housing (notch) or pushed off by
/// other items.
public enum Screens {
    public static func isVisible(_ frame: CGRect) -> Bool {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard let display = displays().first(where: { $0.bounds.contains(center) }) else { return false }
        guard let notched = display.menuBarAreas else { return true }
        // Within the menu bar of a notched display: only the two side areas show items.
        guard center.y < display.bounds.minY + display.menuBarHeight else { return true }
        return notched.contains { $0.contains(frame.insetBy(dx: 1, dy: 1)) }
    }

    /// A point on the empty menu bar, where a click does nothing but close
    /// transient popovers: the middle of the main display's menu bar (the
    /// notch on notched Macs, past the app menus otherwise).
    public static var emptyMenuBarPoint: CGPoint {
        let main = CGDisplayBounds(CGMainDisplayID())
        return CGPoint(x: main.midX, y: main.minY + 4)
    }

    struct Display {
        let bounds: CGRect
        let menuBarHeight: CGFloat
        /// Left and right of the notch in CG coordinates, or `nil` without a notch.
        let menuBarAreas: [CGRect]?
    }

    @MainActor static func displaysOnMain() -> [Display] {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        func flipped(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
        }
        return NSScreen.screens.map { screen in
            let areas = [screen.auxiliaryTopLeftArea, screen.auxiliaryTopRightArea].compactMap(\.self).map(flipped)
            return Display(
                bounds: flipped(screen.frame),
                menuBarHeight: max(screen.safeAreaInsets.top, NSStatusBar.system.thickness),
                menuBarAreas: screen.safeAreaInsets.top > 0 && !areas.isEmpty ? areas : nil
            )
        }
    }

    static func displays() -> [Display] {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { displaysOnMain() }
        }
        return DispatchQueue.main.sync { displaysOnMain() }
    }
}
