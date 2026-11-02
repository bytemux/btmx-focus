// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "btmx-focus",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "BtmxFocus", targets: ["BtmxFocus"]),
        .library(name: "BtmxFocusCore", targets: ["BtmxFocusCore"]),
        .library(name: "BtmxFocusKit", targets: ["BtmxFocusKit"]),
        .executable(name: "focus-drive", targets: ["FocusDrive"]),
    ],
    dependencies: [
        // Test-only: snapshot tests of the views and the status item.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(name: "BtmxFocusCore"),
        // Accessibility identifiers and E2E launch arguments, shared by the
        // app and the E2E driver (ADR 0010).
        .target(name: "BtmxFocusUIContract"),
        .target(name: "BtmxFocusKit", dependencies: ["BtmxFocusCore", "BtmxFocusUIContract"]),
        .executableTarget(name: "BtmxFocus", dependencies: ["BtmxFocusCore", "BtmxFocusKit", "BtmxFocusUIContract"]),
        // E2E: drives the bundled app through Accessibility and real input
        // (ADR 0010). The library backs the E2E suite and `focus-drive`.
        .target(name: "BtmxFocusDriver", dependencies: ["BtmxFocusUIContract"]),
        .executableTarget(name: "FocusDrive", dependencies: ["BtmxFocusDriver", "BtmxFocusUIContract"]),
        .testTarget(name: "BtmxFocusE2ETests", dependencies: ["BtmxFocusDriver", "BtmxFocusUIContract"]),
        // Fakes shared by the test targets. A plain target because SwiftPM
        // can't share code between test targets; only tests depend on it.
        .target(name: "BtmxFocusTestSupport", dependencies: ["BtmxFocusCore", "BtmxFocusKit"]),
        .testTarget(name: "BtmxFocusCoreTests", dependencies: ["BtmxFocusCore"]),
        .testTarget(
            name: "BtmxFocusKitTests",
            dependencies: ["BtmxFocusKit", "BtmxFocusTestSupport", "BtmxFocusUIContract"]
        ),
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
