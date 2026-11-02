import CoreGraphics
import Foundation
import ImageIO

public enum Pixels {
    /// How many pixels in the PNG are clearly red and clearly green, e.g. to
    /// tell a running status-item icon (red/green) from a gray one.
    public static func tint(of url: URL) throws -> (red: Int, green: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw DriverError("Can't read image \(url.path)")
        }
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, // swiftlint:disable:this force_unwrapping
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw DriverError("Can't decode image \(url.path)") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var redPixels = 0
        var greenPixels = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Int(pixels[index])
            let green = Int(pixels[index + 1])
            let blue = Int(pixels[index + 2])
            if red > 180, green < 110, blue < 110 {
                redPixels += 1
            }
            if green > 140, red < 120, blue < 140 {
                greenPixels += 1
            }
        }
        return (redPixels, greenPixels)
    }
}
