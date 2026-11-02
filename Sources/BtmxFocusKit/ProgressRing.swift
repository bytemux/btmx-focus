import AppKit
import SwiftUI

/// The progress ring: a faint full circle with the remaining part of the
/// phase drawn over it, from where the elapsed part ends clockwise back to
/// 12 o'clock. It empties clockwise as the phase runs. Purely visual.
public struct ProgressRing: View {
    /// Elapsed fraction of the phase, 0...1 (`TimerEngine.progress(at:)`).
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    public init(progress: Double, color: Color, lineWidth: CGFloat = 6) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: min(max(progress, 0), 1), to: 1)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}

extension ProgressRing {
    static let menuBarSize = CGSize(width: 16, height: 16)
    static let menuBarLineWidth: CGFloat = 2

    /// The menu-bar icon while Running, the same ring at symbol size.
    static func menuBarImage(progress: Double, color: NSColor) -> NSImage {
        let lineWidth = menuBarLineWidth
        let image = NSImage(size: menuBarSize, flipped: false) { rect in
            let inset = rect.insetBy(dx: lineWidth / 2 + 0.5, dy: lineWidth / 2 + 0.5)
            let track = NSBezierPath(ovalIn: inset)
            track.lineWidth = lineWidth
            color.withAlphaComponent(0.3).setStroke()
            track.stroke()

            guard progress < 1 else { return true }
            // AppKit angles run counter-clockwise from 3 o'clock, so 12 o'clock
            // is 90° and the remaining arc runs clockwise down to -270°.
            // A zero-length sweep draws nothing, so the full ring is an oval.
            let remaining = progress <= 0 ? NSBezierPath(ovalIn: inset) : NSBezierPath()
            if progress > 0 {
                remaining.appendArc(
                    withCenter: CGPoint(x: inset.midX, y: inset.midY), radius: inset.width / 2,
                    startAngle: 90 - 360 * progress, endAngle: -270, clockwise: true
                )
            }
            remaining.lineWidth = lineWidth
            remaining.lineCapStyle = .round
            color.setStroke()
            remaining.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }
}
