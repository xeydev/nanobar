// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NanoBarPluginAPI",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "NanoBarPluginAPI", type: .dynamic, targets: ["NanoBarPluginAPI"]),
    ],
    targets: [
        .target(
            name: "NanoBarPluginAPI",
            path: "Sources/NanoBarPluginAPI",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
