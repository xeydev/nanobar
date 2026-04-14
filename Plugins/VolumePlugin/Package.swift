// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VolumePlugin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VolumePlugin", type: .dynamic, targets: ["VolumePlugin"]),
    ],
    dependencies: [
        .package(path: "../../NanoBarPluginAPI"),
    ],
    targets: [
        .target(
            name: "VolumePlugin",
            dependencies: [
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
