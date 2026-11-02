import Foundation

/// The app's breadcrumbs (every `CrashLog.record`), streamed live from the
/// unified log. Reading `breadcrumbs.log` would mean reaching into the app's
/// sandbox container, which macOS guards with a prompt.
public final class Breadcrumbs: @unchecked Sendable {
    private let process = Process()
    private let lock = NSLock()
    private var buffer = Data()
    private var collected: [String] = []
    private var isLive = false

    /// Starts streaming the E2E build's messages; returns once the stream is live.
    public init(processImagePathContains marker: String) throws {
        process.executableURL = URL(filePath: "/usr/bin/log")
        process.arguments = [
            "stream", "--style", "ndjson", "--level", "info", "--predicate",
            // CrashLog's subsystem.
            "subsystem == \"com.btmx.focus\" AND processImagePath CONTAINS \"\(marker)\"",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.append(handle.availableData)
        }
        try process.run()
        // `log stream` prints a "Filtering the log data…" line once it is live.
        let deadline = Date.now + 5
        while Date.now < deadline, !lock.withLock({ isLive }) {
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard lock.withLock({ isLive }) else {
            stop()
            throw DriverError("`log stream` didn't start within 5 s; breadcrumbs can't be read")
        }
    }

    deinit {
        stop()
    }

    public func stop() {
        guard process.isRunning else { return }
        process.terminate()
    }

    /// Messages so far, oldest first.
    public var lines: [String] {
        lock.withLock { collected }
    }

    public func clear() {
        lock.withLock { collected.removeAll() }
    }

    private func append(_ data: Data) {
        lock.withLock {
            buffer.append(data)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[buffer.startIndex ..< newline]
                buffer.removeSubrange(buffer.startIndex ... newline)
                isLive = true
                let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
                if let message = object?["eventMessage"] as? String {
                    collected.append(message)
                }
            }
        }
    }
}
