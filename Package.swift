// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NanoBar",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.5.0"),
        // Standalone package so the dylib is shared with external plugins at runtime.
        .package(path: "NanoBarPluginAPI"),
    ],
    targets: [
        .executableTarget(
            name: "NowPlayingHelper",
            path: "Sources/NowPlayingHelper",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MonitorsTests",
            dependencies: ["Monitors"],
            path: "Tests/MonitorsTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "NanoBar",
            dependencies: ["Widgets", "Monitors"],
            path: "Sources/NanoBar",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "Widgets",
            dependencies: [
                "Monitors",
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources/Widgets",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "Monitors",
            dependencies: [.product(name: "TOMLKit", package: "TOMLKit")],
            path: "Sources/Monitors",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
