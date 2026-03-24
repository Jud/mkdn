// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OutlineMorph",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "OutlineMorph"),
    ]
)
