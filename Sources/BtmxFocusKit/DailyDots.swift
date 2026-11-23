import SwiftUI

/// Today's progress under the ring: one dot per Focus interval of the daily
/// target, filled as they are completed (●●●○○○○○○○ is 3 of 10), with the
/// count and today's focused time beneath. Intervals over the target show
/// as "+n" after the dots.
public struct DailyDots: View {
    let count: Int
    let target: Int
    let focusedTime: Duration

    public init(count: Int, target: Int, focusedTime: Duration) {
        self.count = count
        self.target = target
        self.focusedTime = focusedTime
    }

    /// Width the dots may take inside the 240-point popover.
    private static let width: CGFloat = 200
    private static let spacing: CGFloat = 4

    /// 10 points, smaller when a large target wouldn't fit in one row.
    private var dotSize: CGFloat {
        let slots = CGFloat(max(1, target))
        return min(10, (Self.width - Self.spacing * (slots - 1)) / slots)
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: Self.spacing) {
                ForEach(0 ..< max(1, target), id: \.self) { index in
                    Circle()
                        .fill(index < count ? AnyShapeStyle(Color.green) : AnyShapeStyle(.quaternary))
                        .frame(width: dotSize, height: dotSize)
                }
                if count > target {
                    Text("+\(count - target)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            Text("Today \(count)/\(target) · \(Self.format(focusedTime))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today \(count) of \(target), \(Self.spokenFormat(focusedTime)) focused"))
    }

    /// "1h 25m", or "25m" under an hour.
    static func format(_ time: Duration) -> String {
        let minutes = Int(time.components.seconds) / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private static func spokenFormat(_ time: Duration) -> String {
        let whole = Duration.seconds(time.components.seconds / 60 * 60)
        return whole.formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }
}
