import CoreGraphics
import Foundation

/// Where screenshots and failure dumps go: `$E2E_OUTPUT_DIR`, or
/// `build/e2e/<timestamp>/` under the current directory (gitignored).
public final class Artifacts: @unchecked Sendable {
    public let directory: URL
    private let lock = NSLock()
    private var counter = 0

    public init(directory: URL? = nil) {
        self.directory = directory ?? Artifacts.defaultDirectory()
    }

    public static func defaultDirectory() -> URL {
        if let path = ProcessInfo.processInfo.environment["E2E_OUTPUT_DIR"], !path.isEmpty {
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        let stamp = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
            .time(includingFractionalSeconds: false).format(.now)
            .replacingOccurrences(of: ":", with: "")
        return URL(filePath: FileManager.default.currentDirectoryPath)
            .appending(path: "build/e2e/\(stamp)", directoryHint: .isDirectory)
    }

    /// `NN-name.ext`, numbered in the order taken. Creates the folder on
    /// first use, so commands that save nothing leave nothing behind.
    public func url(for name: String, ext: String) -> URL {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        lock.lock()
        counter += 1
        let number = counter
        lock.unlock()
        let safe = name.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." ? $0 : "-" }
        return directory.appending(path: String(format: "%02d-", number) + String(safe) + ".\(ext)")
    }

    /// Captures one window (`windowID`), a rectangle of the screen, or the
    /// whole screen. Never prompts: callers preflight Screen Recording.
    @discardableResult
    public func screenshot(_ name: String, windowID: CGWindowID? = nil, rect: CGRect? = nil) throws -> URL {
        let url = url(for: name, ext: "png")
        var arguments = ["-x", "-t", "png"]
        if let windowID {
            arguments += ["-o", "-l", String(windowID)]
        } else if let rect {
            let integral = rect.integral
            arguments += [
                "-R",
                "\(Int(integral.minX)),\(Int(integral.minY)),\(Int(integral.width)),\(Int(integral.height))",
            ]
        }
        try run("/usr/sbin/screencapture", arguments + [url.path])
        return url
    }

    @discardableResult
    public func write(_ text: String, name: String, ext: String = "txt") -> URL {
        let url = url(for: name, ext: ext)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

/// Runs a tool to completion; throws with its output when it fails.
@discardableResult
func run(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(filePath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let output = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw DriverError("\(executable) \(arguments.joined(separator: " ")) failed: \(output)")
    }
    return output
}
