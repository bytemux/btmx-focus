import AppKit

/// The image on a "time for a break" notification: a white tree on a green
/// rounded square, the same tree as the menu-bar icon during a break.
public enum BreakArtwork {
    static let size = CGSize(width: 128, height: 128)

    @MainActor public static let image: NSImage = .init(size: size, flipped: false) { rect in
        let tile = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
        NSGradient(
            starting: NSColor(calibratedRed: 0.36, green: 0.82, blue: 0.45, alpha: 1),
            ending: NSColor(calibratedRed: 0.12, green: 0.56, blue: 0.30, alpha: 1)
        )?.draw(in: tile, angle: -90)
        let configuration = NSImage.SymbolConfiguration(pointSize: 72, weight: .regular)
            .applying(.init(paletteColors: [.white]))
        guard let tree = NSImage(systemSymbolName: "tree.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return true }
        let origin = CGPoint(x: rect.midX - tree.size.width / 2, y: rect.midY - tree.size.height / 2)
        tree.draw(in: CGRect(origin: origin, size: tree.size))
        return true
    }

    /// `image` as PNG, for a notification attachment.
    @MainActor public static var png: Data? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
