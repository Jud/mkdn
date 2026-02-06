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

        // SVG rendering to native NSImage/CGImage
        // Pinned below 0.25.0 to avoid #Preview macro issue in CLI builds
        .package(url: "https://github.com/swhitty/SwiftDraw.git", "0.17.0" ..< "0.25.0"),

        // Swift-friendly JavaScriptCore wrapper
        .package(url: "https://github.com/jectivex/JXKit.git", from: "3.6.0"),

        // Argument parsing for CLI
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),

        // Syntax highlighting
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "mkdnLib",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SwiftDraw", package: "SwiftDraw"),
                .product(name: "JXKit", package: "JXKit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Splash", package: "Splash"),
            ],
            path: "mkdn",
            exclude: ["App/mkdnApp.swift"],
            resources: [
                .copy("Resources/mermaid.min.js"),
            ]
        ),
        .executableTarget(
            name: "mkdn",
            dependencies: ["mkdnLib"],
            path: "mkdnEntry"
        ),
        .testTarget(
            name: "mkdnTests",
            dependencies: ["mkdnLib"],
            path: "mkdnTests"
        ),
    ]
)
