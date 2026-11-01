// swift-tools-version: 6.0
import Foundation
import PackageDescription

/// swift-snapshot-testing imports XCTest, which the Command Line Tools don't
/// ship; there the snapshot tests are left out and the rest still runs.
let toolchainHasXCTest: Bool = {
    let developerDir = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
        ?? (try? FileManager.default.destinationOfSymbolicLink(atPath: "/var/db/xcode_select_link"))
        ?? ""
    let xcTest = "/Platforms/MacOSX.platform/Developer/Library/Frameworks/XCTest.framework"
    return FileManager.default.fileExists(atPath: developerDir + xcTest)
}()

let package = Package(
    name: "btmx-focus",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "BtmxFocus", targets: ["BtmxFocus"]),
        .library(name: "BtmxFocusCore", targets: ["BtmxFocusCore"]),
        .library(name: "BtmxFocusKit", targets: ["BtmxFocusKit"]),
    ],
    dependencies: [
        // Test-only: snapshot tests of the views and the status item.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(name: "BtmxFocusCore"),
        .target(name: "BtmxFocusKit", dependencies: ["BtmxFocusCore"]),
        .executableTarget(name: "BtmxFocus", dependencies: ["BtmxFocusCore", "BtmxFocusKit"]),
        .target(name: "BtmxFocusTestSupport", dependencies: ["BtmxFocusCore", "BtmxFocusKit"]),
        .testTarget(name: "BtmxFocusCoreTests", dependencies: ["BtmxFocusCore"]),
        .testTarget(name: "BtmxFocusKitTests", dependencies: ["BtmxFocusKit", "BtmxFocusTestSupport"]),
    ]
)

if toolchainHasXCTest {
    package.targets.append(.testTarget(
        name: "BtmxFocusSnapshotTests",
        dependencies: [
            "BtmxFocusKit",
            "BtmxFocusTestSupport",
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        ],
        exclude: ["__Snapshots__"]
    ))
}
