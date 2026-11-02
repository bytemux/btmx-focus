import AppKit

/// The app icon (`scripts/make-icon.swift`) at menu-bar size: the progress
/// ring 15% into a phase with a long ƒ over it. A template image, so macOS
/// tints it for a light or dark menu bar. One colour can't layer the ƒ over
/// the ring, so the ring is cut away around the ƒ.
enum MenuBarLogo {
    static let size = CGSize(width: 18, height: 18)

    @MainActor static let image: NSImage = {
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // The icon's 1024-point canvas, cropped to the ƒ's 820-point span.
            context.scaleBy(x: size.width / 820, y: size.height / 820)
            context.translateBy(x: -102, y: -102)

            let ring = NSBezierPath()
            ring.appendArc(
                withCenter: CGPoint(x: 512, y: 512), radius: 300,
                startAngle: 90 - 360 * 0.15, endAngle: -270, clockwise: true
            )
            ring.lineWidth = 72
            ring.lineCapStyle = .round
            NSColor.black.setStroke()
            ring.stroke()

            let curve = NSBezierPath()
            curve.move(to: NSPoint(x: 770, y: 850))
            curve.curve(
                to: NSPoint(x: 600, y: 860), controlPoint1: NSPoint(x: 740, y: 940),
                controlPoint2: NSPoint(x: 630, y: 950)
            )
            curve.curve(
                to: NSPoint(x: 440, y: 170), controlPoint1: NSPoint(x: 560, y: 720),
                controlPoint2: NSPoint(x: 500, y: 300)
            )
            curve.curve(
                to: NSPoint(x: 260, y: 170), controlPoint1: NSPoint(x: 400, y: 80),
                controlPoint2: NSPoint(x: 290, y: 80)
            )
            curve.lineCapStyle = .round
            let crossbar = NSBezierPath()
            crossbar.move(to: NSPoint(x: 400, y: 600))
            crossbar.line(to: NSPoint(x: 660, y: 616))
            crossbar.lineCapStyle = .round

            // A thin gap where the ƒ crosses the ring, then the ƒ.
            context.setBlendMode(.clear)
            curve.lineWidth = 150
            curve.stroke()
            context.setBlendMode(.normal)
            for part in [curve, crossbar] {
                part.lineWidth = 76
                part.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}
