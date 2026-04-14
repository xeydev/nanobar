// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpotifyPlugin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SpotifyPlugin", type: .dynamic, targets: ["SpotifyPlugin"]),
    ],
    dependencies: [
        .package(path: "../../NanoBarPluginAPI"),
    ],
    targets: [
        .target(
            name: "SpotifyPlugin",
            dependencies: [
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
