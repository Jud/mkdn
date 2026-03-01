# mkdnLib iOS Portability — Cross-Platform Rendering Engine

> Research artifact — February 27, 2026

## Context

mkdn's rendering engine is being evaluated for use in the [Sudo](https://github.com/jud/sudo) iPhone app — a native iOS app for interacting with Claude Code agents via a cryptographically authenticated session. The iPhone app needs to render Claude Code's markdown output (conversation messages, code blocks, diffs, plans, tool results) with the same fidelity as mkdn renders documents on Mac.

The question: **how much of mkdnLib's rendering pipeline can run on iOS as-is?**

## Answer: ~90% of the rendering logic, with minimal platform adaptation

The key insight is that mkdn's heaviest module — `MarkdownTextStorageBuilder` (~2,500 LOC) — uses `NSAttributedString`, `NSFont`, `NSColor`, `NSParagraphStyle`, and `NSTextAttachment`. These look like AppKit types but are actually **Foundation types available on iOS**. The builder is iOS-compatible as-is.

## Module-by-Module Assessment

### GREEN — Works on iOS with zero changes

| Module | LOC | Notes |
|--------|-----|-------|
| `MarkdownRenderer` | ~100 | Pure Swift + SwiftUI. Orchestrates parsing. |
| `MarkdownVisitor` | ~300 | Walks swift-markdown AST → `[MarkdownBlock]`. No platform imports. |
| `MarkdownBlock` | ~100 | Enum data model. Pure Swift. |
| `MarkdownTextStorageBuilder` | ~2,500 | Converts blocks → `NSAttributedString`. Uses Foundation types only (NSFont, NSColor, NSParagraphStyle, NSTextAttachment — all available on iOS). |
| `MarkdownTextStorageBuilder+Blocks` | (included above) | Block-level rendering. Same Foundation types. |
| `MarkdownTextStorageBuilder+Complex` | (included above) | Complex inline rendering. Same. |
| `MarkdownTextStorageBuilder+MathInline` | (included above) | Math attachment rendering. Same. |
| `MarkdownTextStorageBuilder+TableInline` | (included above) | Table cell rendering. Same. |
| `AppTheme` / `ThemeColors` | ~150 | Pure SwiftUI `Color`. No platform imports. |
| `TableColumnSizer` | ~200 | Pure computation. Uses `NSFont` for text measurement (available on iOS). |
| `TableCellMap` / `TableAttributes` | ~200 | Pure Swift data structures + custom `NSAttributedString.Key` markers. |
| `MermaidThemeMapper` | ~50 | Pure Swift string mapping. |
| `MermaidRenderState` | ~30 | Pure Swift enum. |
| `TokenType` | ~50 | Tree-sitter token classification. Pure Swift enum. |
| `TreeSitterLanguageMap` | ~100 | Language detection. Pure Swift. |

**Subtotal: ~3,780 LOC — direct iOS compatibility, no changes needed.**

### YELLOW — Needs conditional compilation or thin adapter

| Module | LOC | What's Needed |
|--------|-----|---------------|
| `PlatformTypeConverter` | ~50 | Creates `NSFont`/`NSColor` from SwiftUI types. On macOS uses `NSFont(descriptor:size:)` and `NSColor(color)`. On iOS: `UIFont(descriptor:size:)` and `UIColor(color)`. Solution: `#if os(macOS)` / `#if os(iOS)` branches. ~40 LOC added. |
| `SyntaxHighlightEngine` | ~150 | Builds `NSMutableAttributedString` with color attributes. The output type works on iOS. Only platform-specific call: `PlatformTypeConverter.nsColor()`. Fix: route through conditional converter. ~10 LOC changed. |
| `MathRenderer` | ~50 | Returns `NSImage`. On iOS, return `UIImage`. SwiftMath is pure Swift and works on iOS. Fix: `#if os(macOS)` for image type. ~5 LOC changed. |
| `MathAttributes` | ~30 | Custom `NSAttributedString.Key` + attachment. Works on iOS. May need `NSImage` → `UIImage` in attachment creation. ~5 LOC changed. |

**Subtotal: ~280 LOC — works on iOS with ~60 LOC of conditional compilation.**

### RED — Needs iOS-specific implementation

| Module | LOC | What's Needed |
|--------|-----|---------------|
| `MermaidWebView` | ~400 | `NSViewRepresentable` wrapping `WKWebView`. Needs `UIViewRepresentable` equivalent. The WKWebView setup, HTML template, JavaScript messaging, and theme integration are identical — only the SwiftUI hosting wrapper differs. ~350 LOC new iOS implementation, sharing ~70% of logic. |
| `SelectableTextView` | ~800 | `NSViewRepresentable` wrapping `NSTextView` with TextKit 2 (`NSTextLayoutManager` + `NSTextContentStorage`). Needs iOS equivalent: `UIViewRepresentable` wrapping `UITextView` with TextKit 2 (default since iOS 16, stable on iOS 17). Critical: never access `textView.layoutManager` on iOS as it triggers permanent TextKit 1 fallback. The attributed string it displays is the same cross-platform `NSAttributedString` from the builder. ~600 LOC new iOS implementation. |
| `MarkdownPreviewView` | ~400 | SwiftUI view composing text view + overlays (Mermaid, math, tables). Needs iOS layout adaptation (compact margins, scroll behavior). ~300 LOC new. |
| Other UI components | ~1,500 | Sidebar, editor, window management, orb, find bar — Mac-specific. iPhone app has its own UI shell (conversation view, tool feed, session management). Not ported; replaced by Sudo-specific views. |

**Subtotal: ~3,100 LOC Mac-specific. ~1,250 LOC of new iOS view code needed to display the same rendered content.**

## Summary

```
Total rendering logic:     ~7,160 LOC
Direct iOS share (GREEN):  ~3,780 LOC (53%)
Conditional compile (YELLOW): ~280 LOC (4%)
iOS-specific views (RED):  ~1,250 LOC new (replaces ~3,100 LOC of Mac views)

Effective code sharing:    ~4,060 / ~5,310 total iOS LOC = 76%
```

The parsing pipeline, block model, attributed string builder, theme system, table computation, syntax highlighting, and math rendering are shared. The only iOS-specific work is view hosting (how to display the `NSAttributedString` and embed Mermaid/math overlays).

## What Needs to Change in mkdnLib

### 1. Package.swift — Add iOS platform

```swift
platforms: [
    .macOS(.v14),
    .iOS(.v17),
]
```

iOS 17 minimum gives us: TextKit 2 (stable default for UITextView since iOS 16), SwiftUI improvements (`scrollPosition(id:)`, `containerRelativeFrame`, `@Observable`), UITextViewDelegate text item interaction APIs, ActivityKit.

### 2. PlatformTypeConverter — Conditional compilation

```swift
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum PlatformTypeConverter {
    #if os(macOS)
    typealias PlatformFont = NSFont
    typealias PlatformColor = NSColor
    typealias PlatformImage = NSImage
    #else
    typealias PlatformFont = UIFont
    typealias PlatformColor = UIColor
    typealias PlatformImage = UIImage
    #endif

    static func color(from swiftUIColor: Color) -> PlatformColor {
        PlatformColor(swiftUIColor)
    }

    static func headingFont(level: Int, scaleFactor: CGFloat) -> PlatformFont {
        // Both NSFont and UIFont have .systemFont(ofSize:weight:)
        let size: CGFloat = /* ... */
        return .systemFont(ofSize: size * scaleFactor, weight: weight)
    }
}
```

### 3. SyntaxHighlightEngine — Route through converter

Replace direct `NSColor(color)` calls with `PlatformTypeConverter.color(from:)`.

### 4. MathRenderer — Image type conditional

```swift
static func renderToImage(latex: String, ...) -> (image: PlatformTypeConverter.PlatformImage, baseline: CGFloat)? {
    // SwiftMath works on both platforms
}
```

### 5. New iOS view files (in mkdnLib or in the consuming app)

- `MarkdownTextViewiOS.swift` — `UIViewRepresentable` hosting `UITextView` with the shared `NSAttributedString`
- `MermaidWebViewiOS.swift` — `UIViewRepresentable` hosting `WKWebView` with the shared HTML template
- `MarkdownPreviewViewiOS.swift` — SwiftUI composition for iOS layout

## Architecture After Refactoring

```
mkdnLib (shared library — macOS + iOS)
├── Core/
│   ├── Markdown/
│   │   ├── MarkdownRenderer.swift          [shared]
│   │   ├── MarkdownVisitor.swift           [shared]
│   │   ├── MarkdownBlock.swift             [shared]
│   │   ├── MarkdownTextStorageBuilder*.swift [shared — Foundation types]
│   │   ├── TableColumnSizer.swift          [shared]
│   │   ├── TableCellMap.swift              [shared]
│   │   ├── TableAttributes.swift           [shared]
│   │   └── PlatformTypeConverter.swift     [conditional compilation]
│   ├── Highlighting/
│   │   ├── SyntaxHighlightEngine.swift     [shared, routes through converter]
│   │   ├── TreeSitterLanguageMap.swift      [shared]
│   │   └── TokenType.swift                 [shared]
│   ├── Math/
│   │   ├── MathRenderer.swift              [conditional image type]
│   │   └── MathAttributes.swift            [shared]
│   └── Mermaid/
│       ├── MermaidThemeMapper.swift         [shared]
│       └── MermaidRenderState.swift         [shared]
├── UI/
│   └── Theme/
│       ├── AppTheme.swift                  [shared]
│       └── ThemeColors.swift               [shared]
└── Platform/
    ├── macOS/
    │   ├── SelectableTextView.swift        [Mac only]
    │   ├── MermaidWebView.swift            [Mac only]
    │   └── MarkdownPreviewView.swift       [Mac only]
    └── iOS/
        ├── MarkdownTextViewiOS.swift       [iOS only — new]
        ├── MermaidWebViewiOS.swift         [iOS only — new]
        └── MarkdownPreviewViewiOS.swift    [iOS only — new]
```

## Synergy with Sudo iPhone App

The Sudo iPhone app imports `mkdnLib` and gets:

- **Conversation rendering**: Claude Code's markdown messages rendered with full fidelity — headings, code blocks with 16-language syntax highlighting, tables, inline math, Mermaid diagrams
- **Diff rendering**: When mkdn builds its diff viewer (roadmap M7), the same component renders diffs on both Mac and iPhone
- **Solarized theming**: Shared color palette, both platforms look cohesive
- **Code block rendering**: Same tree-sitter highlighting engine for tool_use/tool_result display

The daemon sends NDJSON events. The iPhone app parses `message.content[].text` as markdown, passes it through `MarkdownRenderer.render()`, gets back `[IndexedBlock]`, feeds it to `MarkdownTextStorageBuilder.build()`, gets an `NSAttributedString`, and displays it in a `UITextView`. Same pipeline as mkdn on Mac.

## Open Questions

1. **Should the iOS views live in mkdnLib or in the Sudo app?** If mkdnLib is going to be a general-purpose rendering library, the iOS views belong in mkdnLib. If it's tightly coupled to the mkdn Mac app, the Sudo app provides its own views.
2. **Mermaid on mobile**: Is it worth rendering Mermaid diagrams on iPhone? They're often wide and hard to read on a phone screen. Could show a "tap to expand" thumbnail instead.
3. **Performance on older iPhones**: The full attributed string pipeline is fast on Mac. Need to verify it doesn't cause jank on iPhone SE-class hardware, especially for long Claude Code conversations.
4. **Incremental rendering**: Claude Code streams tokens. mkdn re-renders the full document on change. For mobile, consider incremental append to the attributed string for streaming responses.
