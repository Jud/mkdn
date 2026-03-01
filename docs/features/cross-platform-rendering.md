# Feature: Cross-Platform Rendering

> mkdnLib compiles for macOS 14.0+ and iOS 17.0+, sharing the parsing pipeline, block model, attributed string builder, theme system, syntax highlighting, and math rendering across both platforms.

## Overview

mkdnLib's rendering engine targets both macOS and iOS from a single library target. The core pipeline -- markdown parsing, AST visitation, block model, `NSAttributedString` construction, syntax highlighting, math rendering, and theme resolution -- is platform-agnostic. Platform-specific code is isolated behind conditional compilation (`#if os(macOS)` / `#if os(iOS)`) in a small number of files, primarily `PlatformTypeConverter` which provides typealiases and bridge methods that abstract AppKit vs UIKit differences.

## Portability Breakdown

**Shared across platforms (~90% of rendering logic):**
- `MarkdownRenderer`, `MarkdownVisitor`, `MarkdownBlock` -- pure Swift parsing pipeline
- `MarkdownTextStorageBuilder` and all extensions -- `NSAttributedString` construction using Foundation types (`NSFont`, `NSColor`, `NSParagraphStyle`, `NSTextAttachment` are available on both platforms)
- `SyntaxHighlightEngine`, `TreeSitterLanguageMap`, `TokenType` -- tree-sitter highlighting
- `MathRenderer`, `MathAttributes` -- LaTeX rendering via SwiftMath
- `AppTheme`, `ThemeColors` -- SwiftUI `Color` palette
- `TableColumnSizer`, `TableCellMap`, `TableAttributes` -- table computation
- `MermaidThemeMapper`, `MermaidRenderState` -- Mermaid configuration

**Conditional compilation (~60 LOC of `#if` branches):**
- `PlatformTypeConverter` -- typealiases (`PlatformFont`/`PlatformColor`/`PlatformImage`), `FontTrait` OptionSet bridging `NSFontTraitMask` vs `UIFontDescriptor.SymbolicTraits`, color/font factory methods

**Platform-specific views (separate implementations per platform):**
- `SelectableTextView` -- `NSViewRepresentable` (macOS) wrapping `NSTextView`; iOS equivalent would use `UIViewRepresentable` wrapping `UITextView`
- `MermaidWebView` -- `NSViewRepresentable` (macOS) wrapping `WKWebView`; iOS equivalent uses `UIViewRepresentable`
- `MarkdownPreviewView` -- SwiftUI composition with platform-specific layout

## Architecture

```
mkdnLib (shared library -- macOS + iOS)
├── Core/
│   ├── Markdown/
│   │   ├── MarkdownRenderer.swift              [shared]
│   │   ├── MarkdownVisitor.swift               [shared]
│   │   ├── MarkdownBlock.swift                 [shared]
│   │   ├── MarkdownTextStorageBuilder*.swift    [shared -- Foundation types]
│   │   ├── TableColumnSizer.swift              [shared]
│   │   ├── TableCellMap.swift                  [shared]
│   │   └── PlatformTypeConverter.swift         [conditional compilation]
│   ├── Highlighting/                           [shared]
│   ├── Math/                                   [conditional image type]
│   └── Mermaid/                                [shared config, platform-specific views]
├── UI/Theme/                                   [shared]
├── Features/Viewer/                            [macOS-specific views]
└── App/                                        [macOS-specific shell]
```

## Key Design Decisions

1. **Foundation types as the portability layer**: `NSFont`, `NSColor`, `NSParagraphStyle`, and `NSTextAttachment` are Foundation types available on iOS (despite the `NS` prefix). The entire `MarkdownTextStorageBuilder` (~2,500 LOC) works on iOS without changes because it builds `NSAttributedString` using these Foundation types.

2. **PlatformTypeConverter as the single abstraction point**: Rather than scattering `#if os(macOS)` throughout the codebase, all platform-specific type references route through `PlatformTypeConverter`. Core rendering files use `PlatformTypeConverter.PlatformFont` instead of `NSFont`/`UIFont` directly.

3. **FontTrait OptionSet**: Font trait conversion differs significantly between platforms (`NSFontManager.shared.convert(_:toHaveTrait:)` on macOS vs `UIFontDescriptor.withSymbolicTraits(_:)` on iOS). The `FontTrait` OptionSet (`.bold`, `.italic`) provides a unified API that `convertFont(_:toHaveTrait:)` dispatches to the correct platform implementation.

4. **Conditional dependency for ArgumentParser**: `swift-argument-parser` is macOS-only in mkdnLib (`.when(platforms: [.macOS])`). CLI argument parsing, file validation, and launch context are guarded with `#if os(macOS)` since iOS apps do not use command-line entry points.

5. **Same NSAttributedString, different display views**: The rendering pipeline produces identical `NSAttributedString` output on both platforms. Only the final display step differs: `NSTextView` on macOS, `UITextView` on iOS.

## Package.swift Configuration

```swift
platforms: [
    .macOS(.v14),
    .iOS(.v17),
]
```

iOS 17 minimum provides: TextKit 1 (stable), SwiftUI improvements, `NSAttributedString` full compatibility.

ArgumentParser is conditional in the library target:
```swift
.product(
    name: "ArgumentParser",
    package: "swift-argument-parser",
    condition: .when(platforms: [.macOS])
)
```

## Files

| File | Role |
|------|------|
| `Package.swift` | Declares `.macOS(.v14)` and `.iOS(.v17)` platforms; conditional ArgumentParser dependency |
| `mkdn/Core/Markdown/PlatformTypeConverter.swift` | Cross-platform abstraction hub: typealiases, FontTrait, color/font bridge methods |
| `docs/ios-portability.md` | Research artifact: module-by-module iOS portability assessment |

## Dependencies

- **Internal**: `PlatformTypeConverter` is consumed by `MarkdownTextStorageBuilder`, `SyntaxHighlightEngine`, `MathRenderer`, and all code that creates platform fonts or colors
- **External**: All external dependencies (swift-markdown, SwiftTreeSitter, SwiftMath) are pure Swift and compile for both platforms. ArgumentParser is macOS-only conditional.

## Testing

Cross-platform rendering correctness is verified through the existing `PlatformTypeConverterTests` which test font mapping, color conversion, and paragraph style properties. The `MarkdownTextStorageBuilder` test suite validates attributed string output regardless of platform since it exercises the shared Foundation types.