// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PomodoroPlugin",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PomodoroPlugin", type: .dynamic, targets: ["PomodoroPlugin"]),
    ],
    dependencies: [
        .package(path: "../../NanoBarPluginAPI"),
    ],
    targets: [
        .target(
            name: "PomodoroPlugin",
            dependencies: [
                .product(name: "NanoBarPluginAPI", package: "NanoBarPluginAPI"),
            ],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
