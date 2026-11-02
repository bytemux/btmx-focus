import ApplicationServices
import CoreGraphics
import Darwin

/// Checks the permissions the driver needs without ever showing a prompt.
/// macOS grants them to the app that started the process (the terminal or
/// editor), not to the test binary.
public enum Permissions {
    public static func preflight() throws {
        var missing: [String] = []
        if !AXIsProcessTrusted() {
            missing.append("Privacy & Security → Accessibility (to read and press the app's controls)")
        }
        if !CGPreflightScreenCaptureAccess() {
            missing.append("Privacy & Security → Screen & System Audio Recording (for screenshots and window titles)")
        }
        guard !missing.isEmpty else { return }
        throw DriverError("""
        The E2E driver lacks permissions. In System Settings, allow \(hostApp()) under:
        \(missing.map { "  - \($0)" }.joined(separator: "\n"))
        then quit and reopen that app and run again.
        """)
    }

    /// The outermost `.app` among this process's ancestors: the app macOS
    /// holds responsible for it (Terminal, iTerm, an editor, …).
    public static func hostApp() -> String {
        var pid = getpid()
        var host: String?
        while pid > 1 {
            if let path = executablePath(of: pid), let range = path.range(of: ".app/") {
                host = String(path[..<range.lowerBound]) + ".app"
            }
            pid = parent(of: pid)
        }
        return host.map { "\"\($0)\"" } ?? "the terminal app you ran this from"
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(bytes: buffer.prefix(Int(length)), encoding: .utf8)
    }

    private static func parent(of pid: pid_t) -> pid_t {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return 0 }
        return info.kp_eproc.e_ppid
    }
}
