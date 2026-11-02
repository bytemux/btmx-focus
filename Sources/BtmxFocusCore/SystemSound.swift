/// The built-in macOS sounds (`/System/Library/Sounds`) the end-of-phase
/// sound can be picked from. "None" is stored as an empty name.
public enum SystemSound {
    public static let names = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]
}

public extension Preferences {
    /// The sound played when `phase` ends, or nil for "None".
    func endSound(after phase: Phase) -> String? {
        let name = switch phase {
        case .focus: focusEndSound
        case .rest, .longRest: breakEndSound
        }
        return name.isEmpty ? nil : name
    }

    /// The sound to play when `phase` ends: nil for "None", or while a Focus
    /// mode (or Do Not Disturb) is on and the user wants silence then.
    /// `focusActive` is nil when the Focus status can't be read; the sound
    /// then plays, since the end of a phase must be noticed (ADR 0007).
    func endSound(after phase: Phase, focusActive: Bool?) -> String? {
        silentDuringFocus && focusActive == true ? nil : endSound(after: phase)
    }
}
