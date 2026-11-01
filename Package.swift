// swift-tools-version: 6.0
import PackageDescription

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
        // Fakes shared by the test targets. A plain target because SwiftPM
        // can't share code between test targets; only tests depend on it.
        .target(name: "BtmxFocusTestSupport", dependencies: ["BtmxFocusCore", "BtmxFocusKit"]),
        .testTarget(name: "BtmxFocusCoreTests", dependencies: ["BtmxFocusCore"]),
        .testTarget(name: "BtmxFocusKitTests", dependencies: ["BtmxFocusKit", "BtmxFocusTestSupport"]),
        .testTarget(
            name: "BtmxFocusSnapshotTests",
            dependencies: [
                "BtmxFocusKit",
                "BtmxFocusTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"]
        ),
    ]
)
