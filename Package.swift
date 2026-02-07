// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "mkdn",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "mkdn",
            targets: ["mkdn"]
        ),
    ],
    dependencies: [
        // Markdown parsing (Apple's official parser)
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "mkdnLib",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Splash", package: "Splash"),
            ],
            path: "mkdn",
            resources: [
            ]
        ),
        .executableTarget(
            name: "mkdn",
            dependencies: ["mkdnLib"],
            path: "mkdnEntry",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "mkdnTests",
            dependencies: ["mkdnLib"],
            path: "mkdnTests"
        ),
    ]
)
