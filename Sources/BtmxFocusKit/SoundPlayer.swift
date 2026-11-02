import AppKit

/// Plays a built-in system sound by name (see `SystemSound`).
@MainActor
public protocol SoundPlayer: AnyObject {
    /// `volume` is `NSSound.volume`, 0...1.
    func play(_ name: String, volume: Double)
}

@MainActor
public final class SystemSoundPlayer: SoundPlayer {
    /// The sound playing now, kept so a preview isn't deallocated mid-play and
    /// a new preview cuts off the previous one.
    private var current: NSSound?

    public init() {}

    public func play(_ name: String, volume: Double) {
        current?.stop()
        // A copy: `NSSound(named:)` returns a shared instance, whose volume
        // would leak into other users of that sound.
        guard let sound = NSSound(named: name)?.copy() as? NSSound else { return }
        sound.volume = Float(volume)
        sound.play()
        current = sound
    }
}
