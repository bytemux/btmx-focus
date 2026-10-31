import Darwin
import Foundation
import os

// State the fatal-signal handler reads. Global and unsynchronized so the
// handler can use it without locks; only plain bytes and file descriptors.
private nonisolated(unsafe) var pendingCrashPath: UnsafeMutablePointer<CChar>?
private nonisolated(unsafe) var recentText: UnsafeMutablePointer<UInt8>?
private nonisolated(unsafe) var recentTextLength = 0
private nonisolated(unsafe) var debugFD: Int32 = -1
private let recentTextCapacity = 16 * 1024

/// Records user actions so a crash leaves behind what the user did last,
/// without touching the disk during normal use.
///
/// - The last 50 actions live in memory only, pre-rendered as crash-report text.
/// - A fatal signal (including Swift runtime traps) writes that text to
///   `crash-pending.log`, then the process crashes as usual so macOS still
///   writes its `.ips` report. The next launch renames it to `crash-<date>.log`
///   and keeps the 5 newest.
/// - Debug logging (off by default, `⋯` menu) also appends every action to
///   `breadcrumbs.log`, rotated at 512 KB with one previous file kept (≤ 1 MB).
///
/// Logs live in `~/Library/Containers/com.btmx.focus/Data/Library/Logs/btmx-focus/`
/// for the sandboxed app, or `~/Library/Logs/btmx-focus/` under `swift run`.
@MainActor
enum CrashLog {
    static let directory = URL.libraryDirectory.appending(path: "Logs/btmx-focus", directoryHint: .isDirectory)
    static let debugLoggingKey = "debugLogging"

    private static let pendingCrashURL = directory.appending(path: "crash-pending.log")
    private static let breadcrumbsURL = directory.appending(path: "breadcrumbs.log")
    private static let previousBreadcrumbsURL = directory.appending(path: "breadcrumbs.previous.log")
    private static let logger = Logger(subsystem: "com.btmx.focus", category: "actions")
    private static let fatalSignals = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]
    private static let maxRecentActions = 50
    private static let maxCrashLogs = 5
    private static let maxBreadcrumbsBytes = 512 * 1024
    /// Local time with offset, matching the times in macOS crash reports.
    private static let timestamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)

    private static var recentActions: [String] = []
    private static var breadcrumbsBytes = 0

    /// Call once, first thing at launch.
    static func start() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        keepPreviousCrash()
        pruneCrashLogs()

        pendingCrashPath = strdup(pendingCrashURL.path)
        recentText = .allocate(capacity: recentTextCapacity)
        for signal in fatalSignals {
            Darwin.signal(signal, handleFatalSignal)
        }

        setDebugLogging(UserDefaults.standard.bool(forKey: debugLoggingKey))
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        record("launch btmx-focus \(version)")
    }

    static func record(_ message: String) {
        logger.info("\(message, privacy: .public)")
        let line = "\(Date.now.formatted(timestamp)) \(message)"
        recentActions.append(line)
        if recentActions.count > maxRecentActions {
            recentActions.removeFirst()
        }
        renderRecentText()
        appendBreadcrumb(line + "\n")
    }

    static func setDebugLogging(_ enabled: Bool) {
        if enabled, debugFD < 0 {
            openBreadcrumbs(truncate: false)
        } else if !enabled, debugFD >= 0 {
            close(debugFD)
            debugFD = -1
        }
    }

    static func markCleanExit() {
        record("quit")
    }

    /// Crash text the signal handler writes after its own "FATAL …" line.
    private static func renderRecentText() {
        guard let buffer = recentText else { return }
        let text = """
        Last action: \(recentActions.last ?? "none recorded")
        Full macOS crash report: ~/Library/Logs/DiagnosticReports/btmx-focus-*.ips

        Recent actions (oldest first):
        \(recentActions.joined(separator: "\n"))

        """
        let bytes = Array(text.utf8.prefix(recentTextCapacity))
        recentTextLength = 0
        bytes.withUnsafeBufferPointer { buffer.update(from: $0.baseAddress!, count: $0.count) }
        recentTextLength = bytes.count
    }

    private static func appendBreadcrumb(_ line: String) {
        guard debugFD >= 0 else { return }
        if breadcrumbsBytes >= maxBreadcrumbsBytes {
            close(debugFD)
            let files = FileManager.default
            try? files.removeItem(at: previousBreadcrumbsURL)
            try? files.moveItem(at: breadcrumbsURL, to: previousBreadcrumbsURL)
            openBreadcrumbs(truncate: true)
        }
        breadcrumbsBytes += line.withCString { write(debugFD, $0, strlen($0)) }
    }

    private static func openBreadcrumbs(truncate: Bool) {
        let flags = O_WRONLY | O_CREAT | O_APPEND | (truncate ? O_TRUNC : 0)
        debugFD = open(breadcrumbsURL.path, flags, 0o644)
        let attributes = try? FileManager.default.attributesOfItem(atPath: breadcrumbsURL.path)
        breadcrumbsBytes = attributes?[.size] as? Int ?? 0
    }

    /// Renames the crash text written by the previous session's signal handler.
    private static func keepPreviousCrash() {
        let files = FileManager.default
        guard files.fileExists(atPath: pendingCrashURL.path) else { return }
        let crashedAt = modificationDate(pendingCrashURL)
        let stamp = Date.ISO8601FormatStyle(timeZone: .current).format(crashedAt)
            .replacingOccurrences(of: ":", with: "-")
        try? files.moveItem(at: pendingCrashURL, to: directory.appending(path: "crash-\(stamp).log"))
    }

    private static func pruneCrashLogs() {
        let files = FileManager.default
        let crashLogs = (try? files.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ))?
            .filter { $0.lastPathComponent.hasPrefix("crash-") && $0.pathExtension == "log" } ?? []
        let newestFirst = crashLogs.sorted { modificationDate($0) > modificationDate($1) }
        for url in newestFirst.dropFirst(maxCrashLogs) {
            try? files.removeItem(at: url)
        }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}

/// Runs inside a signal handler: only async-signal-safe calls (`open`, `write`,
/// `close`, `signal`, `raise`) on preallocated memory.
private func handleFatalSignal(_ signal: Int32) {
    let message: StaticString = switch signal {
    case SIGTRAP: "FATAL SIGTRAP (Swift runtime trap)\n"
    case SIGABRT: "FATAL SIGABRT (abort / uncaught exception)\n"
    case SIGSEGV: "FATAL SIGSEGV (bad memory access)\n"
    case SIGBUS: "FATAL SIGBUS (bad memory access)\n"
    case SIGILL: "FATAL SIGILL (illegal instruction)\n"
    default: "FATAL signal\n"
    }
    if let path = pendingCrashPath {
        let crashFD = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        if crashFD >= 0 {
            _ = write(crashFD, message.utf8Start, message.utf8CodeUnitCount)
            if let text = recentText {
                _ = write(crashFD, text, recentTextLength)
            }
            close(crashFD)
        }
    }
    if debugFD >= 0 {
        _ = write(debugFD, message.utf8Start, message.utf8CodeUnitCount)
    }
    Darwin.signal(signal, SIG_DFL)
    raise(signal)
}
