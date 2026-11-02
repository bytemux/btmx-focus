import AppKit
import BtmxFocusCore
import BtmxFocusKit
import BtmxFocusTestSupport
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

/// Reference images live in `__Snapshots__/` next to this file and are
/// committed, recorded on macOS 27 in the light appearance.
/// `SNAPSHOT_RECORD=1 swift test` re-records them all (expected after macOS
/// updates); a missing reference is recorded and fails once.
private let recordMode: SnapshotTestingConfiguration.Record =
    ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1" ? .all : .missing

@MainActor
@Suite(.snapshots(record: recordMode))
struct SnapshotTests {
    @Test(arguments: PopoverState.allCases)
    func popover(state: PopoverState) async {
        let harness = TimerHarness()
        await state.drive(harness)
        // The ⋯ menu's Debug Logging toggle reads @AppStorage; keep it off
        // the test process's real defaults.
        let view = PopoverView(model: harness.model, openSettings: {})
            .defaultAppStorage(freshDefaults().defaults)
        assertSnapshot(of: view, size: CGSize(width: 240, height: 280), named: state.rawValue)
    }

    /// Each tab's content without the tab bar, which offscreen rendering
    /// can't draw (its selected segment comes out blank).
    @Test(arguments: SettingsTab.allCases)
    func settings(tab: SettingsTab) {
        let store = SettingsStore(defaults: freshDefaults().defaults)
        let launchAtLogin = LaunchAtLogin(service: FakeLoginItemService(), center: NotificationCenter())
        let view = SettingsTabContent(tab: tab, settings: store, launchAtLogin: launchAtLogin)
        assertSnapshot(of: view, size: CGSize(width: 460, height: 260), named: "\(tab)")
    }

    @Test(arguments: [
        ("ready", TimerState.ready(.focus)),
        ("running", .running(.focus, endDate: TimerHarness.t0 + 1453)),
        ("runningRest", .running(.rest, endDate: TimerHarness.t0 + 75)),
    ])
    func statusItem(name: String, state: TimerState) {
        let presentation = StatusItemPresentation(
            engine: TimerEngine(state: state), preferences: Preferences(), now: TimerHarness.t0
        )
        let button = NSButton(frame: CGRect(x: 0, y: 0, width: 80, height: 24))
        button.isBordered = false
        presentation.apply(to: button)
        assertSnapshot(of: backed(button), as: .image(perceptualPrecision: 0.98), named: name)
    }
}

enum PopoverState: String, CaseIterable {
    case readyFocus
    case runningFocus
    case paused
    case readyRest
    case readyLongRest

    /// Gets a fresh model into this state, 5 min 47 s into Focus where the
    /// clock has moved.
    @MainActor
    func drive(_ harness: TimerHarness) async {
        switch self {
        case .readyFocus:
            break
        case .runningFocus:
            harness.model.play()
            await harness.clock.advance(by: 347)
        case .paused:
            harness.model.play()
            await harness.clock.advance(by: 347)
            harness.model.pause()
        case .readyRest:
            harness.model.skip()
        case .readyLongRest:
            // One 1 s Focus interval per cycle, so its end loads a long break.
            harness.model.setSchedule(Schedule(
                focus: .seconds(1), rest: .seconds(5 * 60), longRest: .seconds(15 * 60), longRestEvery: 1
            ))
            harness.model.play()
            await harness.clock.advance(by: 1)
        }
    }
}

/// Renders `view` at a fixed size on the window background, in the light
/// appearance.
@MainActor
private func assertSnapshot(
    of view: some View, size: CGSize, named name: String,
    fileID: StaticString = #fileID, file: StaticString = #filePath, testName: String = #function,
    line: UInt = #line, column: UInt = #column
) {
    let host = NSHostingView(rootView: view)
    host.frame = CGRect(origin: .zero, size: size)
    assertSnapshot(
        of: backed(host), as: .image(perceptualPrecision: 0.98), named: name,
        fileID: fileID, file: file, testName: testName, line: line, column: column
    )
}

/// `content` on an opaque window-background view in the light appearance,
/// whatever the Mac running the tests is set to.
@MainActor
private func backed(_ content: NSView) -> NSView {
    let background = NSBox(frame: content.frame)
    background.boxType = .custom
    background.borderWidth = 0
    background.fillColor = .windowBackgroundColor
    background.contentViewMargins = .zero
    background.contentView = content
    background.appearance = NSAppearance(named: .aqua)
    return background
}
