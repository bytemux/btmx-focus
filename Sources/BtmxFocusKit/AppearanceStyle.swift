import AppKit
import BtmxFocusCore

public extension Appearance {
    /// What to assign to a window's or popover's `appearance`: `nil` inherits
    /// the system's light or dark mode.
    var nsAppearance: NSAppearance? {
        switch self {
        case .auto: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
