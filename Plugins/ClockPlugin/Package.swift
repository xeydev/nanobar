// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClockPlugin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ClockPlugin", type: .dynamic, targets: ["ClockPlugin"]),
    ],
    dependencies: [
        .package(path: "../../NanoBarPluginAPI"),
    ],
    targets: [
        .target(
            name: "ClockPlugin",
            dependencies: [
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ClockPluginTests",
            dependencies: ["ClockPlugin"],
            path: "Tests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
