import AppKit
import BtmxFocusCore
import BtmxFocusKit
import Testing

@MainActor
struct AppearanceTests {
    @Test func autoFollowsTheSystem() {
        #expect(Appearance.auto.nsAppearance == nil)
    }

    @Test func lightAndDarkForceAqua() {
        #expect(Appearance.light.nsAppearance?.name == .aqua)
        #expect(Appearance.dark.nsAppearance?.name == .darkAqua)
    }
}
