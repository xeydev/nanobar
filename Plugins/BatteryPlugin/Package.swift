// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BatteryPlugin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "BatteryPlugin", type: .dynamic, targets: ["BatteryPlugin"]),
    ],
    dependencies: [
        .package(path: "../../NanoBarPluginAPI"),
    ],
    targets: [
        .target(
            name: "BatteryPlugin",
            dependencies: [
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
