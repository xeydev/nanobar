// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyboardPlugin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "KeyboardPlugin", type: .dynamic, targets: ["KeyboardPlugin"]),
    ],
    dependencies: [
        .package(path: "../../NanoBarPluginAPI"),
    ],
    targets: [
        .target(
            name: "KeyboardPlugin",
            dependencies: [
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
