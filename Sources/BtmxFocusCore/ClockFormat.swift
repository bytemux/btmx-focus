import Foundation

public enum ClockFormat {
    /// Whole seconds shown for `remaining`, rounded up so `00:00` appears
    /// only at the deadline.
    public static func displayedSeconds(_ remaining: Duration) -> Int {
        Int(max(0, remaining.timeInterval).rounded(.up))
    }

    /// `mm:ss`, or `h:mm:ss` from one hour up.
    public static func string(for remaining: Duration) -> String {
        let total = displayedSeconds(remaining)
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
