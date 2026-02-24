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

        // Tree-sitter syntax highlighting
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.25.0"),

        // Tree-sitter grammar packages (16 languages)
        // Pinned to 0.23.x/0.7.x ranges for consistent ChimeHQ/SwiftTreeSitter references
        // and static source lists in Package.swift (newer versions use FileManager detection
        // which breaks when built as a dependency).
        .package(
            url: "https://github.com/alex-pinkus/tree-sitter-swift.git",
            revision: "277b583bbb024f20ba88b95c48bf5a6a0b4f2287"
        ),
        .package(url: "https://github.com/tree-sitter/tree-sitter-python.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-javascript.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-typescript.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-rust.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-go.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-bash.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-json.git", "0.24.0" ..< "0.25.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-html.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-css.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-c.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-cpp.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-ruby.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-java.git", "0.23.0" ..< "0.24.0"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-yaml.git", exact: "0.7.0"),
        .package(url: "https://github.com/fwcd/tree-sitter-kotlin.git", from: "0.3.0"),

        // LaTeX math rendering
        .package(url: "https://github.com/mgriebling/SwiftMath.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "mkdnLib",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
                .product(name: "TreeSitterPython", package: "tree-sitter-python"),
                .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript"),
                .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
                .product(name: "TreeSitterRust", package: "tree-sitter-rust"),
                .product(name: "TreeSitterGo", package: "tree-sitter-go"),
                .product(name: "TreeSitterBash", package: "tree-sitter-bash"),
                .product(name: "TreeSitterJSON", package: "tree-sitter-json"),
                .product(name: "TreeSitterHTML", package: "tree-sitter-html"),
                .product(name: "TreeSitterCSS", package: "tree-sitter-css"),
                .product(name: "TreeSitterC", package: "tree-sitter-c"),
                .product(name: "TreeSitterCPP", package: "tree-sitter-cpp"),
                .product(name: "TreeSitterRuby", package: "tree-sitter-ruby"),
                .product(name: "TreeSitterJava", package: "tree-sitter-java"),
                .product(name: "TreeSitterYAML", package: "tree-sitter-yaml"),
                .product(name: "TreeSitterKotlin", package: "tree-sitter-kotlin"),
                .product(name: "SwiftMath", package: "SwiftMath"),
            ],
            path: "mkdn",
            resources: [
                .copy("Resources/mermaid.min.js"),
                .copy("Resources/mermaid-template.html"),
                .copy("Resources/AppIcon.icns"),
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
