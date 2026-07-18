// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SSATPrep",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SSATCore"),
        .executableTarget(name: "SSATPrep", dependencies: ["SSATCore"]),
        .testTarget(name: "SSATCoreTests", dependencies: ["SSATCore"]),
    ]
)
