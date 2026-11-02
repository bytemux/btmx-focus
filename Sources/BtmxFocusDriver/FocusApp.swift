import AppKit
import ApplicationServices
import BtmxFocusUIContract
import CoreGraphics

/// Drives the bundled E2E build of btmx-focus from outside the process, the
/// way a user would: through what the Accessibility API shows and real
/// clicks and key presses (ADR 0010).
///
/// - `E2E_APP` overrides the app's path (default `build/btmx-focus E2E.app`).
public final class FocusApp: @unchecked Sendable {
    public static let defaultTimeout: TimeInterval = 2
    public static let pollInterval: TimeInterval = 0.05
    public static let launchSettleTime: TimeInterval = 1

    public let appURL: URL
    public let artifacts: Artifacts
    public private(set) var pid: pid_t?
    public private(set) var breadcrumbs: Breadcrumbs?

    public init(appURL: URL = FocusApp.defaultAppURL, artifacts: Artifacts = Artifacts()) {
        self.appURL = appURL
        self.artifacts = artifacts
    }

    public static var defaultAppURL: URL {
        if let path = ProcessInfo.processInfo.environment["E2E_APP"], !path.isEmpty {
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        return URL(filePath: FileManager.default.currentDirectoryPath)
            .appending(path: "build/\(E2EContract.appName).app", directoryHint: .isDirectory)
    }

    // MARK: Launch and quit

    /// Arguments every test launch uses: no notification prompt, breadcrumbs
    /// on, and no idle skip (the driver is idle while it waits for a phase end).
    public static let quietArguments = [
        E2EContract.Argument.noNotifications, E2EContract.Argument.debugLogging, E2EContract.Argument.noIdleSkip,
    ]

    /// Quits any running E2E instance, then launches a new one in the
    /// background and waits for its status item. Breadcrumbs are collected
    /// from just before launch.
    public func launch(_ arguments: [String] = []) throws {
        try Permissions.preflight()
        guard Input.held.isEmpty else {
            throw DriverError("""
            \(Input.held.joined(separator: "+")) is held down. Let go; if nothing is pressed, a previous run \
            leaked it: `swift run focus-drive release`.
            """)
        }
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw DriverError("No app at \(appURL.path); build it with scripts/build-app.sh e2e")
        }
        if let running = Self.runningPID() {
            pid = running
            try quit()
        }
        breadcrumbs?.stop()
        breadcrumbs = try Breadcrumbs(processImagePathContains: "\(E2EContract.appName).app/")
        try run("/usr/bin/open", ["-g", appURL.path, "--args"] + arguments)
        try waitUntil("the app is running", timeout: 10) { Self.runningPID() != nil }
        pid = Self.runningPID()
        _ = try statusItem(timeout: 10)
        try waitForBreadcrumb(containing: "e2e build:", timeout: 10) // ends applicationDidFinishLaunching
        // The menu bar (hosted outside the app) takes a moment to route clicks
        // to a new status item, and there's no signal for it from outside:
        // clicks within ~0.5 s of launch are sometimes lost.
        Thread.sleep(forTimeInterval: Self.launchSettleTime)
    }

    /// Attaches to an E2E instance that is already running (used by `focus-drive`).
    public func attach() throws {
        try Permissions.preflight()
        guard let running = Self.runningPID() else {
            throw DriverError("\(E2EContract.appName) isn't running; start it with `focus-drive launch`")
        }
        pid = running
    }

    /// Asks the app to quit and waits until it has; kills it if it hangs.
    public func quit(timeout: TimeInterval = 5) throws {
        guard let pid else { return }
        NSRunningApplication(processIdentifier: pid)?.terminate()
        do {
            try waitUntil("the app has quit", timeout: timeout) { !isAlive(pid) }
        } catch {
            kill(pid, SIGKILL)
            throw error
        }
        self.pid = nil
    }

    /// Whether the app is the active one, which gets the keyboard.
    public var isFrontmost: Bool {
        (try? application().attribute(kAXFrontmostAttribute) as? Bool) ?? false
    }

    /// One line for failure dumps and `focus-drive state`: which app has the
    /// keyboard and what input the system thinks is held, e.g.
    /// `frontmost=com.apple.Terminal e2eFrontmost=false held=cmd`.
    public func inputState() -> String {
        let focused = AXElement(AXUIElementCreateSystemWide()).element(kAXFocusedApplicationAttribute)
        var focusedPID: pid_t = 0
        if let focused {
            AXUIElementGetPid(focused.raw, &focusedPID)
        }
        // AX asks the window server live; NSWorkspace's answer can be stale in
        // a process without a run loop, so it's only the fallback.
        let frontmost = NSRunningApplication(processIdentifier: focusedPID)?.bundleIdentifier
            ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        let held = Input.held.isEmpty ? "none" : Input.held.joined(separator: "+")
        return "frontmost=\(frontmost) e2eFrontmost=\(isFrontmost) held=\(held)"
    }

    /// Releases modifiers left held by the run (so they don't follow the user
    /// into other apps) and names them; nil when the input was clean.
    public func releaseLeakedInput() -> String? {
        let held = Input.held
        guard !held.isEmpty else { return nil }
        Input.releaseModifiers()
        return held.joined(separator: "+")
    }

    public var isRunning: Bool {
        pid.map(isAlive) ?? false
    }

    public static func runningPID() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: E2EContract.bundleIdentifier)
            .first { !$0.isTerminated }?.processIdentifier
    }

    private func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    // MARK: Finding elements

    public func application() throws -> AXElement {
        guard let pid, isAlive(pid) else { throw DriverError("\(E2EContract.appName) isn't running") }
        return .application(pid: pid)
    }

    /// The app's own menu-bar extras: its status item.
    public func statusItem(timeout: TimeInterval = defaultTimeout) throws -> AXElement {
        try wait(for: "status item \(AccessibilityID.statusItem)", timeout: timeout) {
            try self.extrasMenuBar()?.first { $0.identifier == AccessibilityID.statusItem }
        }
    }

    /// The element with this identifier, or `nil`. Searches the windows
    /// (popover, Settings), open menus and the status item.
    public func find(_ identifier: String) throws -> AXElement? {
        try application().first { $0.identifier == identifier }
    }

    /// Waits for the element with this identifier (see `find`).
    public func element(_ identifier: String, timeout: TimeInterval = defaultTimeout) throws -> AXElement {
        try wait(for: "element \(identifier)", timeout: timeout) { try self.find(identifier) }
    }

    public func isShown(_ identifier: String) -> Bool {
        (try? find(identifier)) != nil
    }

    private func extrasMenuBar() throws -> AXElement? {
        try application().element("AXExtrasMenuBar")
    }

    // MARK: Input

    /// Clicks the element's centre with the real mouse. Fails
    /// when the element isn't on screen, e.g. a status item hidden behind the
    /// notch or by menu-bar overflow.
    public func click(_ element: AXElement) throws {
        let frame = try settledFrame(of: element)
        guard Screens.isVisible(frame) else {
            throw DriverError("""
            \(element.summary) isn't visible on screen (behind the notch or hidden by menu-bar overflow?). \
            Make room in the menu bar, e.g. quit other menu-bar apps, and run again.
            """)
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        try waitUntil("\(element.summary) to be what's under its centre") { isHit(element, at: center) }
        Input.click(at: center)
    }

    /// Whether a click at `point` would reach `element`: the topmost element
    /// there is it or inside it. AX frames are final while a popover still
    /// animates in, and then the point can be over another control.
    private func isHit(_ element: AXElement, at point: CGPoint) -> Bool {
        var current = elementAt(point)
        for _ in 0 ..< 10 {
            guard let candidate = current else { return false }
            if CFEqual(candidate.raw, element.raw) {
                return true
            }
            current = candidate.element(kAXParentAttribute)
        }
        return false
    }

    /// The topmost element at `point`, in any app.
    private func elementAt(_ point: CGPoint) -> AXElement? {
        var hit: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success
        else { return nil }
        return hit.map(AXElement.init)
    }

    /// The element's frame once it has stopped moving: a new status item
    /// slides into the menu bar and the popover animates open, and a click
    /// at a stale position misses.
    private func settledFrame(of element: AXElement) throws -> CGRect {
        var last = element.frame
        return try wait(for: "\(element.summary) to stop moving") {
            Thread.sleep(forTimeInterval: 0.1)
            let current = element.frame
            defer { last = current }
            return current != nil && current == last ? current : nil
        }
    }

    public func click(_ identifier: String) throws {
        try click(element(identifier))
    }

    public func clickStatusItem() throws {
        try click(statusItem())
    }

    /// Clicks the empty middle of the menu bar, outside the app.
    /// Refuses if that spot holds a menu or menu-bar item, which the click
    /// would open.
    public func clickOutside() throws {
        let point = Screens.emptyMenuBarPoint
        let role = elementAt(point)?.role
        guard role == kAXMenuBarRole else {
            throw DriverError(
                "The middle of the menu bar isn't empty (\(role ?? "nothing") there); can't click outside"
            )
        }
        Input.click(at: point)
    }

    /// e.g. `space`, `cmd+w`. Goes to the active app, like typing.
    public func key(_ keys: String) throws {
        try Input.press(keys)
    }

    // MARK: Waiting

    /// Polls every 50 ms until `condition` holds; throws after `timeout`.
    public func waitUntil(
        _ description: String, timeout: TimeInterval = defaultTimeout, _ condition: () throws -> Bool
    ) throws {
        _ = try wait(for: description, timeout: timeout) { try condition() ? true : nil }
    }

    /// Polls until `produce` returns a value; throws after `timeout`.
    public func wait<Value>(
        for description: String, timeout: TimeInterval = defaultTimeout, _ produce: () throws -> Value?
    ) throws -> Value {
        let deadline = Date.now + timeout
        var lastError: Error?
        repeat {
            do {
                if let value = try produce() {
                    return value
                }
            } catch {
                lastError = error
            }
            Thread.sleep(forTimeInterval: Self.pollInterval)
        } while Date.now < deadline
        let reason = lastError.map { " (last error: \($0))" } ?? ""
        throw DriverError("Timed out after \(timeout) s waiting for \(description)\(reason)")
    }

    /// Where the breadcrumbs are now, for `waitForBreadcrumb(containing:since:)`.
    public var breadcrumbMark: Int {
        breadcrumbs?.lines.count ?? 0
    }

    /// Waits for a breadcrumb containing `text`, written after `mark` (default:
    /// any since launch).
    public func waitForBreadcrumb(
        containing text: String, since mark: Int = 0, timeout: TimeInterval = defaultTimeout
    ) throws {
        try waitUntil("breadcrumb \"\(text)\"", timeout: timeout) {
            breadcrumbs?.lines.dropFirst(mark).contains { $0.contains(text) } ?? false
        }
    }

    // MARK: Screenshots and dumps

    /// A named checkpoint: the status item with the popover and its open ⋯
    /// menu under it, plus the Settings window (if open).
    @discardableResult
    public func screenshot(_ name: String) throws -> [URL] {
        var urls: [URL] = []
        var area = try statusItem().frame ?? .zero
        if let popover = try find(AccessibilityID.Popover.root)?.frame {
            area = area.union(popover)
        }
        // Only the ⋯ menu: the hidden main menu's menus are in the AX tree too,
        // with frames at the screen's origin.
        if let menu = try find(AccessibilityID.Popover.more)?.first(where: { $0.role == kAXMenuRole })?.frame {
            area = area.union(menu)
        }
        try urls.append(artifacts.screenshot(name, rect: area.insetBy(dx: -12, dy: -12)))
        if let windowID = settingsWindowID() {
            try urls.append(artifacts.screenshot("\(name)-settings", windowID: windowID))
        }
        return urls
    }

    /// The status item alone, for colour checks.
    public func statusItemImage(_ name: String) throws -> URL {
        guard let frame = try statusItem().frame else { throw DriverError("status item has no frame") }
        return try artifacts.screenshot(name, rect: frame)
    }

    /// The Settings window's `CGWindowID`, if it is on screen.
    public func settingsWindowID() -> CGWindowID? {
        guard let pid else { return nil }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.first {
            $0[kCGWindowOwnerPID as String] as? pid_t == pid
                && ($0[kCGWindowName as String] as? String)?.hasSuffix("Settings") == true
        }?[kCGWindowNumber as String] as? CGWindowID
    }

    /// The app's whole AX tree, status item and open menus included.
    public func tree() throws -> String {
        try application().dump()
    }

    /// For a failed test: `…-FAILED.txt` (input state, error, AX tree,
    /// breadcrumbs) and a checkpoint screenshot of the app, if it's running.
    public func saveFailureArtifacts(_ name: String, error: Error) {
        let state = inputState()
        _ = try? screenshot("\(name)-FAILED")
        let tree = (try? tree()) ?? "(app not running)"
        let crumbs = breadcrumbs?.lines.joined(separator: "\n") ?? ""
        artifacts.write(
            "\(state)\n\n\(error)\n\nAX tree:\n\(tree)\n\nBreadcrumbs:\n\(crumbs)\n", name: "\(name)-FAILED"
        )
    }
}
