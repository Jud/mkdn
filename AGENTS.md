# Agent Instructions for mkdn

## Project Overview

mkdn is a Mac-native Markdown viewer and editor built with Swift 6 and SwiftUI.
It targets macOS 14.0+ (Sonoma) and uses SPM for dependency management.

## Critical Constraints

- **NO WKWebView anywhere in the codebase.** The entire app is native SwiftUI.
- Mermaid rendering uses JavaScriptCore (via JXKit) + beautiful-mermaid, NOT a web view.
- SVG output from Mermaid is rasterized via SwiftDraw, displayed as native Image.

## Architecture

- **Pattern**: Feature-Based MVVM
- **Source layout**: `mkdn/` (source), `mkdnTests/` (tests)
- **Entry point**: `mkdn/App/mkdnApp.swift`
- **State**: `AppState` is the central observable state, passed via SwiftUI environment

## Code Style

- Swift 6 with strict concurrency
- SwiftLint strict mode (all opt-in rules enabled, `strict: true`)
- SwiftFormat with 4-space indentation, before-first wrapping
- Line length: 120 warning, 150 error
- Use `@Observable` (Observation framework), not `ObservableObject`
- Use Swift Testing (`@Test`, `#expect`, `@Suite`) for new unit tests
- Use XCTest only for UI automation tests

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| UI Framework | SwiftUI | Native, declarative, modern |
| Markdown parsing | apple/swift-markdown | Official, well-maintained |
| Markdown rendering | Custom SwiftUI visitor | Full control, native performance |
| Mermaid rendering | JSC + beautiful-mermaid | No DOM required, in-process |
| SVG to native | SwiftDraw | Lightweight SVG rasterizer |
| JSC interface | JXKit | Swift-friendly JSC wrapper |
| Syntax highlighting | Splash | Swift-native, no web views |
| File watching | DispatchSource | Kernel-level, efficient |
| Theming | Solarized (Dark/Light) | Terminal-consistent |

## Testing

Run all tests:
```bash
swift test
```

Tests use Swift Testing framework. Organize in `@Suite` structs.
Prefer `#expect` over XCTest assertions for all non-UI tests.

## Dependencies

All managed via SPM in Package.swift:
- apple/swift-markdown
- swhitty/SwiftDraw
- jectivex/JXKit
- apple/swift-argument-parser
- JohnSundell/Splash
