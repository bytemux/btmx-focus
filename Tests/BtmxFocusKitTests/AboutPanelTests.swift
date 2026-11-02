import AppKit
import BtmxFocusKit
import Testing

struct AboutPanelTests {
    @Test func showsTheBuildCommitAsTheVersion() {
        let options = AboutPanel.options(info: [AboutPanel.commitKey: "178a0ef", "CFBundleVersion": "1"])
        #expect(options[.applicationVersion] as? String == "178a0ef")
        // An empty build number hides the "(1)" after the version.
        #expect(options[.version] as? String == "")
    }

    /// `swift run`: no bundle, so no stamped commit.
    @Test func showsDevWithoutAStampedCommit() {
        let options = AboutPanel.options(info: [:])
        #expect(options[.applicationVersion] as? String == "dev")
    }
}
