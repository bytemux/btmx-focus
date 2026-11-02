// Draws the app icon's two layers: the red progress ring and, over it, a long
// italic ƒ whose hooks stick out past the ring. Writes them as 1024-point
// PNGs into the Icon Composer icon, whose icon.json stacks them on the
// background and adds the Liquid Glass; `scripts/build-app.sh` compiles it.
//   swift scripts/make-icon.swift Support/AppIcon.icon/Assets
import AppKit

let assets = URL(fileURLWithPath: CommandLine.arguments[1])
try! FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

func layer(_ name: String, draw: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSGraphicsContext.current!.cgContext)
    try! rep.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent(name))
}

let red = NSColor(srgbRed: 0.90, green: 0.22, blue: 0.20, alpha: 1)
let ink = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)

// The progress ring 15% into a phase (ProgressRing.menuBarImage): the
// remaining arc from there clockwise back to 12 o'clock.
layer("ring.png") { _ in
    let ring = NSBezierPath()
    ring.appendArc(
        withCenter: CGPoint(x: 512, y: 512), radius: 300,
        startAngle: 90 - 360 * 0.15, endAngle: -270, clockwise: true
    )
    ring.lineWidth = 84
    ring.lineCapStyle = .round
    red.setStroke()
    ring.stroke()
}

/// The ƒ: top hook curling right, a long slanted spine, bottom hook curling
/// left, both hooks past the ring; then the crossbar. A round brush stamped
/// along the curve swells from thin hook ends to a thick spine, like a pen
/// stroke.
typealias Cubic = (CGPoint, CGPoint, CGPoint, CGPoint)

func point(_ c: Cubic, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    let a = u * u * u, b = 3 * u * u * t, d = 3 * u * t * t, e = t * t * t
    return CGPoint(
        x: a * c.0.x + b * c.1.x + d * c.2.x + e * c.3.x,
        y: a * c.0.y + b * c.1.y + d * c.2.y + e * c.3.y
    )
}

layer("f.png") { cg in
    let ƒ: [Cubic] = [
        (CGPoint(x: 770, y: 850), CGPoint(x: 740, y: 940), CGPoint(x: 630, y: 950), CGPoint(x: 600, y: 860)),
        (CGPoint(x: 600, y: 860), CGPoint(x: 560, y: 720), CGPoint(x: 500, y: 300), CGPoint(x: 440, y: 170)),
        (CGPoint(x: 440, y: 170), CGPoint(x: 400, y: 80), CGPoint(x: 290, y: 80), CGPoint(x: 260, y: 170)),
    ]
    let steps = 600
    ink.setFill()
    for (i, cubic) in ƒ.enumerated() {
        for step in 0 ... steps {
            let t = CGFloat(step) / CGFloat(steps)
            // 0 at the hook ends, 1 in the middle of the spine.
            let along = (CGFloat(i) + t) / CGFloat(ƒ.count)
            let radius = 22 + 22 * sin(along * .pi)
            let p = point(cubic, t)
            cg.fillEllipse(in: CGRect(x: p.x - radius, y: p.y - radius, width: 2 * radius, height: 2 * radius))
        }
    }

    let crossbar = NSBezierPath()
    crossbar.move(to: NSPoint(x: 400, y: 600))
    crossbar.line(to: NSPoint(x: 660, y: 616))
    crossbar.lineWidth = 50
    crossbar.lineCapStyle = .round
    ink.setStroke()
    crossbar.stroke()
}
