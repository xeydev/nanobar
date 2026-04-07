// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NanoBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "NanoBar",
            dependencies: ["Widgets", "Monitors", "AeroSpaceClient"],
            path: "Sources/NanoBar",
            resources: [.copy("sketchybar-app-font.ttf")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "Widgets",
            dependencies: ["AeroSpaceClient", "Monitors"],
            path: "Sources/Widgets",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "Monitors",
            dependencies: ["AeroSpaceClient"],
            path: "Sources/Monitors",
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
