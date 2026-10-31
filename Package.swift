// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "btmx-focus",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "BtmxFocus", targets: ["BtmxFocus"]),
        .library(name: "BtmxFocusCore", targets: ["BtmxFocusCore"]),
    ],
    targets: [
        .target(name: "BtmxFocusCore"),
        .executableTarget(name: "BtmxFocus", dependencies: ["BtmxFocusCore"]),
        .testTarget(name: "BtmxFocusCoreTests", dependencies: ["BtmxFocusCore"]),
    ]
)
