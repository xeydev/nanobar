// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AeroSpacePlugin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AeroSpacePlugin", type: .dynamic, targets: ["AeroSpacePlugin"]),
    ],
    dependencies: [
        .package(path: "../../NanoBarPluginAPI"),
    ],
    targets: [
        .target(
            name: "AeroSpacePlugin",
            dependencies: [
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
