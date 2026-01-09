// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "LyraCopyMVP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .executable(name: "LyraCopyCLI", targets: ["LyraCopyCLI"]),
        .executable(name: "LyraCopyUI", targets: ["LyraCopyUI"])    
    ],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "LyraCopyCLI",
            dependencies: ["Core"],
            path: "Sources/CLI"
        ),
        .executableTarget(
            name: "LyraCopyUI",
            dependencies: ["Core"],
            path: "Sources/UI"
        )
    ]
)
