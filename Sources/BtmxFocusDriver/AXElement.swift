import ApplicationServices
import CoreGraphics

/// A thin, read-only wrapper over an Accessibility element of another app.
/// Frames are in global screen coordinates with the origin at the top left
/// of the main display, like `CGEvent` locations.
public struct AXElement: @unchecked Sendable {
    public let raw: AXUIElement

    public init(_ raw: AXUIElement) {
        self.raw = raw
    }

    public static func application(pid: pid_t) -> AXElement {
        AXElement(AXUIElementCreateApplication(pid))
    }

    public func attribute(_ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(raw, name as CFString, &value) == .success else { return nil }
        return value
    }

    public func element(_ name: String) -> AXElement? {
        guard let value = attribute(name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AXElement(value as! AXUIElement) // swiftlint:disable:this force_cast
    }

    public func string(_ name: String) -> String? {
        attribute(name) as? String
    }

    public var role: String? { string(kAXRoleAttribute) }
    public var subrole: String? { string(kAXSubroleAttribute) }
    public var identifier: String? { string(kAXIdentifierAttribute) }
    public var title: String? { string(kAXTitleAttribute) }
    public var label: String? { string(kAXDescriptionAttribute) }
    public var isEnabled: Bool { attribute(kAXEnabledAttribute) as? Bool ?? true }

    /// Text for static text, 0/1 for checkboxes and toggles.
    public var value: Any? { attribute(kAXValueAttribute) }

    public var children: [AXElement] {
        (attribute(kAXChildrenAttribute) as? [AXUIElement] ?? []).map(AXElement.init)
    }

    public var windows: [AXElement] {
        (attribute(kAXWindowsAttribute) as? [AXUIElement] ?? []).map(AXElement.init)
    }

    public var frame: CGRect? {
        guard let positionValue = attribute(kAXPositionAttribute),
              let sizeValue = attribute(kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        return CGRect(origin: origin, size: size)
    }

    /// Depth-first search of this element and everything below it.
    public func first(where matches: (AXElement) -> Bool, maxDepth: Int = 40) -> AXElement? {
        if matches(self) {
            return self
        }
        guard maxDepth > 0 else { return nil }
        for child in children {
            if let found = child.first(where: matches, maxDepth: maxDepth - 1) {
                return found
            }
        }
        return nil
    }

    /// One line: role, identifier, title, label, value and frame.
    public var summary: String {
        var parts = [role ?? "?"]
        if let subrole {
            parts.append("(\(subrole))")
        }
        if let identifier {
            parts.append("id=\(identifier)")
        }
        if let title, !title.isEmpty {
            parts.append("title=\"\(title)\"")
        }
        if let label, !label.isEmpty {
            parts.append("label=\"\(label)\"")
        }
        if let value {
            parts.append("value=\"\(value)\"")
        }
        if !isEnabled {
            parts.append("disabled")
        }
        if let frame {
            parts.append("@(\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))")
        }
        return parts.joined(separator: " ")
    }

    /// The indented tree below this element, one `summary` per line.
    public func dump(maxDepth: Int = 40) -> String {
        var lines: [String] = []
        func visit(_ element: AXElement, depth: Int) {
            lines.append(String(repeating: "  ", count: depth) + element.summary)
            guard depth < maxDepth else { return }
            for child in element.children {
                visit(child, depth: depth + 1)
            }
        }
        visit(self, depth: 0)
        return lines.joined(separator: "\n")
    }
}

public struct DriverError: Error, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}
