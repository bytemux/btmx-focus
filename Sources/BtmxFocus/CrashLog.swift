import Darwin
import Foundation
import os

/// File descriptor of the current session's breadcrumb file. Global and
/// unsynchronized so the fatal-signal handler can write to it without locks.
private nonisolated(unsafe) var breadcrumbFD: Int32 = -1

/// Breadcrumb trail of user actions, written straight to disk so a crash
/// leaves behind what the user did last.
///
/// - Every `record` call appends one line to `breadcrumbs.log`, unbuffered.
/// - A fatal signal (including Swift runtime traps) appends a `FATAL` line,
///   then the process crashes as usual so macOS still writes its `.ips` report.
/// - A `running` marker exists while the app runs. If it is still there at the
///   next launch, the previous session ended abnormally and its breadcrumbs are
///   saved as `crash-<date>.log`.
///
/// Logs live in `~/Library/Containers/com.btmx.focus/Data/Library/Logs/btmx-focus/`
/// for the sandboxed app, or `~/Library/Logs/btmx-focus/` under `swift run`.
enum CrashLog {
    static let directory = URL.libraryDirectory.appending(path: "Logs/btmx-focus", directoryHint: .isDirectory)

    private static let breadcrumbsURL = directory.appending(path: "breadcrumbs.log")
    private static let markerURL = directory.appending(path: "running")
    private static let logger = Logger(subsystem: "com.btmx.focus", category: "actions")
    private static let fatalSignals = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]
    /// Local time with offset, matching the times in macOS crash reports.
    private static let timestamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)

    /// Call once, first thing at launch.
    static func start() {
        let files = FileManager.default
        try? files.createDirectory(at: directory, withIntermediateDirectories: true)

        if files.fileExists(atPath: markerURL.path) {
            savePreviousSession()
        }
        files.createFile(atPath: markerURL.path, contents: nil)

        breadcrumbFD = open(breadcrumbsURL.path, O_WRONLY | O_CREAT | O_TRUNC | O_APPEND, 0o644)
        for signal in fatalSignals {
            Darwin.signal(signal, handleFatalSignal)
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        record("launch btmx-focus \(version)")
    }

    static func record(_ message: String) {
        logger.info("\(message, privacy: .public)")
        guard breadcrumbFD >= 0 else { return }
        let line = "\(Date.now.formatted(timestamp)) \(message)\n"
        _ = line.withCString { write(breadcrumbFD, $0, strlen($0)) }
    }

    /// Call from `applicationWillTerminate`.
    static func markCleanExit() {
        record("quit")
        try? FileManager.default.removeItem(at: markerURL)
    }

    private static func savePreviousSession() {
        let lines = (try? String(contentsOf: breadcrumbsURL, encoding: .utf8))?
            .split(separator: "\n") ?? []
        let lastAction = lines.last { !$0.contains(" FATAL ") } ?? "none recorded"
        let fatal = lines.last { $0.contains(" FATAL ") }

        let crashLine = fatal.map { "Crash: \($0.trimmingCharacters(in: .whitespaces))" }
            ?? "No fatal signal recorded (force quit, power loss or hang)."

        let report = """
        btmx-focus did not exit cleanly in the previous session.
        \(crashLine)
        Last action: \(lastAction)
        Full macOS crash reports: ~/Library/Logs/DiagnosticReports/btmx-focus-*.ips

        Breadcrumbs (oldest first):
        \(lines.suffix(100).joined(separator: "\n"))

        """
        let stamp = Date.ISO8601FormatStyle(timeZone: .current).format(.now).replacingOccurrences(of: ":", with: "-")
        try? report.write(to: directory.appending(path: "crash-\(stamp).log"), atomically: true, encoding: .utf8)
    }
}

/// Runs inside a signal handler: only async-signal-safe calls (`write`,
/// `signal`, `raise`) and no allocation.
private func handleFatalSignal(_ signal: Int32) {
    let message: StaticString = switch signal {
    case SIGTRAP: " FATAL SIGTRAP (Swift runtime trap)\n"
    case SIGABRT: " FATAL SIGABRT (abort / uncaught exception)\n"
    case SIGSEGV: " FATAL SIGSEGV (bad memory access)\n"
    case SIGBUS: " FATAL SIGBUS (bad memory access)\n"
    case SIGILL: " FATAL SIGILL (illegal instruction)\n"
    default: " FATAL signal\n"
    }
    if breadcrumbFD >= 0 {
        _ = write(breadcrumbFD, message.utf8Start, message.utf8CodeUnitCount)
    }
    Darwin.signal(signal, SIG_DFL)
    raise(signal)
}
