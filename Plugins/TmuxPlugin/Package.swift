// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TmuxPlugin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TmuxPlugin", type: .dynamic, targets: ["TmuxPlugin"]),
    ],
    dependencies: [
        // Same standalone package the host app links against — shared dylib at runtime.
        .package(path: "../../NanoBarPluginAPI"),
    ],
    targets: [
        .target(
            name: "TmuxPlugin",
            dependencies: [
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
