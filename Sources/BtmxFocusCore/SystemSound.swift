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
        case .rest: breakEndSound
        }
        return name.isEmpty ? nil : name
    }
}
