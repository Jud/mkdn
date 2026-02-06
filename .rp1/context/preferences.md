# Project Preferences
**Generated**: 2026-02-06 | **Status**: Complete

## Technology Stack

| Category | Choice | Version | Rationale |
|----------|--------|---------|-----------|
| Language | Swift | 6 | Apple's modern language with strict concurrency |
| Platform | macOS | 14.0+ (Sonoma) | Minimum for latest SwiftUI features |
| UI Framework | SwiftUI | Latest | Native, declarative, modern Apple UI |
| Package Manager | SPM | Built-in | Standard Swift dependency management |
| Build System | Xcode 16+ / SPM | Latest | Official Apple toolchain |
| Testing | Swift Testing + XCTest | Swift 6 | Swift Testing for unit, XCTest for UI |
| Linting | SwiftLint | 0.63.2 | Strict mode, all opt-in rules |
| Formatting | SwiftFormat | 0.59.1 | Consistent code style enforcement |

## Dependencies

| Package | Purpose | Rationale |
|---------|---------|-----------|
| apple/swift-markdown | Markdown parsing | Official Apple parser, well-maintained |
| swhitty/SwiftDraw | SVG to NSImage | Lightweight SVG rasterizer, no web view |
| jectivex/JXKit | JavaScriptCore wrapper | Swift-friendly JSC interface for Mermaid |
| apple/swift-argument-parser | CLI arguments | Official Apple CLI parsing |
| JohnSundell/Splash | Syntax highlighting | Swift-native code highlighting |

## Architecture Decisions

| Decision | Choice | Alternatives Considered |
|----------|--------|------------------------|
| No WKWebView | Fully native SwiftUI | WKWebView for Markdown/Mermaid (rejected: heavyweight, non-native) |
| Mermaid rendering | JSC + beautiful-mermaid | WKWebView + mermaid.js (rejected: requires DOM) |
| State management | @Observable | ObservableObject (rejected: legacy Combine pattern) |
| Project structure | Feature-Based MVVM | Flat structure (rejected: poor scalability) |
| Theme system | Solarized (Dark/Light) | System colors (rejected: terminal-consistency requirement) |

## Code Style

- 4-space indentation
- 120-character line length (warning), 150 (error)
- Before-first argument wrapping
- Trailing commas mandatory
- LF line endings
- No file headers (stripped by SwiftFormat)
