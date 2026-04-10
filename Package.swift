// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NanoBar",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "NowPlayingHelper",
            path: "Sources/NowPlayingHelper",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "NanoBar",
            dependencies: ["Widgets", "Monitors", "AeroSpaceClient", "NanoBarKit"],
            path: "Sources/NanoBar",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "Widgets",
            dependencies: ["AeroSpaceClient", "Monitors", "NanoBarKit"],
            path: "Sources/Widgets",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "Monitors",
            dependencies: ["AeroSpaceClient", .product(name: "TOMLKit", package: "TOMLKit")],
            path: "Sources/Monitors",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "NanoBarKit",
            dependencies: [],
            path: "Sources/NanoBarKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AeroSpaceClient",
            dependencies: [],
            path: "Sources/AeroSpaceClient",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
