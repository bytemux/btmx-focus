import AppKit
import CoreGraphics

/// Real mouse and keyboard input through `CGEvent`, as if from the hardware.
/// The pointer is put back where it was after every click.
public enum Input {
    public static func click(at point: CGPoint) {
        let saved = CGEvent(source: nil)?.location
        post(.mouseMoved, at: point)
        pause()
        post(.leftMouseDown, at: point)
        pause()
        post(.leftMouseUp, at: point)
        // A busy app handles the click late and checks where the pointer is
        // then; moving it away too soon turns the click into a drag-off.
        Thread.sleep(forTimeInterval: 0.3)
        if let saved {
            CGWarpMouseCursorPosition(saved)
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }

    /// `keys` is a key name with optional modifiers: `space`, `cmd+w`, `escape`.
    /// Modifiers are pressed and released like on a keyboard; a flag alone
    /// on the key event leaves the system thinking the modifier is still down.
    public static func press(_ keys: String) throws {
        let (code, modifiers) = try parse(keys)
        var flags = CGEventFlags()
        for modifier in modifiers {
            flags.insert(modifier.flag)
            post(key: modifier.code, down: true, flags: flags)
        }
        post(key: code, down: true, flags: flags)
        post(key: code, down: false, flags: flags)
        for modifier in modifiers.reversed() {
            flags.remove(modifier.flag)
            post(key: modifier.code, down: false, flags: flags)
        }
    }

    private static func post(key: CGKeyCode, down: Bool, flags: CGEventFlags) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
        pause()
    }

    private static func post(_ type: CGEventType, at point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        event?.setIntegerValueField(.mouseEventClickState, value: 1)
        event?.post(tap: .cghidEventTap)
    }

    private static func pause() {
        Thread.sleep(forTimeInterval: 0.05)
    }

    struct Modifier {
        let flag: CGEventFlags
        let code: CGKeyCode
    }

    static func parse(_ keys: String) throws -> (CGKeyCode, [Modifier]) {
        var parts = keys.lowercased().split(separator: "+").map(String.init)
        guard let name = parts.popLast(), let code = keyCodes[name] else {
            throw DriverError("Unknown key in \"\(keys)\"; known: \(keyCodes.keys.sorted().joined(separator: " "))")
        }
        let modifiers = try parts.map { name in
            guard let modifier = modifiers[name] else {
                throw DriverError("Unknown modifier \"\(name)\"; known: \(modifiers.keys.sorted())")
            }
            return modifier
        }
        return (code, modifiers)
    }

    private static let modifiers: [String: Modifier] = [
        "cmd": Modifier(flag: .maskCommand, code: 55),
        "shift": Modifier(flag: .maskShift, code: 56),
        "alt": Modifier(flag: .maskAlternate, code: 58),
        "option": Modifier(flag: .maskAlternate, code: 58),
        "ctrl": Modifier(flag: .maskControl, code: 59),
    ]

    /// Modifiers and mouse buttons the system thinks are held right now, e.g.
    /// `["cmd"]`. A key down without its key up (a crashed or buggy run)
    /// stays held for every app, turning clicks into ⌘-clicks.
    public static var held: [String] {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let keys = heldModifierNames.filter { flags.contains($0.flag) }.map(\.name)
        let buttons: [(String, CGMouseButton)] = [("left mouse", .left), ("right mouse", .right)]
        return keys + buttons.filter { CGEventSource.buttonState(.combinedSessionState, button: $0.1) }.map(\.0)
    }

    /// Releases every modifier (left and right keys), whatever holds it.
    public static func releaseModifiers() {
        for code: CGKeyCode in [55, 54, 56, 60, 58, 61, 59, 62] {
            post(key: code, down: false, flags: [])
        }
    }

    private static let heldModifierNames: [(name: String, flag: CGEventFlags)] = [
        ("cmd", .maskCommand), ("shift", .maskShift), ("alt", .maskAlternate), ("ctrl", .maskControl),
    ]

    /// ANSI US layout virtual key codes.
    private static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38,
        "k": 40, "n": 45, "m": 46, ",": 43, "comma": 43, ".": 47,
        "return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53, "esc": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]
}
