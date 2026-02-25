# Print Support

## Overview

Cmd+P prints any Markdown document with a dedicated ink-efficient palette -- white
background, black text, light gray code blocks, WCAG AA syntax colors -- regardless
of the active screen theme. The on-screen view is saved beforehand and restored
after the print operation completes, so no flicker or theme flash occurs. Tables
receive full print rendering (header fill, alternating rows, divider) drawn directly
by the text view since SwiftUI overlays are absent during print.

## User Experience

Press Cmd+P (or File > Print). The standard macOS print dialog appears with
print-friendly content already in the preview. No configuration, no theme switching,
no new UI. After printing or cancelling, the screen returns to the active theme
instantly. Page Setup (Cmd+Shift+P) is also wired in the menu.

## Architecture

The print path reuses the existing rendering pipeline with substituted colors:

1. `MkdnCommands` dispatches `printView(_:)` to the first responder
   `CodeBlockBackgroundTextView` found in the key window's view hierarchy.
2. `CodeBlockBackgroundTextView.printView(_:)` saves the current attributed string
   and background color, then rebuilds via `MarkdownTextStorageBuilder.build(blocks:
   colors:syntaxColors:isPrint:)` using `PrintPalette` values.
3. The rebuilt string is set on the same text view. An `NSPrintOperation` runs
   against `self`, which causes `drawBackground(in:)` to fire -- drawing code block
   containers with the print palette colors embedded in `CodeBlockColorInfo`.
4. `drawTableContainers(in:)` (in `+TablePrint`) is gated on
   `NSPrintOperation.current != nil`. During print it reads `TableAttributes` from
   the text storage, computes geometry from layout fragments, and draws rounded
   borders, header fills, alternating row fills, and a header-body divider with
   `NSBezierPath`.
5. After the print operation completes, the original attributed string and background
   color are restored on the text view.

## Implementation Decisions

- **PrintPalette is not an AppTheme case.** It is a separate caseless enum with
  static `colors` and `syntaxColors` properties, keeping it out of the theme picker
  and cycle.
- **In-place swap, not temporary view.** The text view's content is replaced for
  the duration of the print operation and restored afterward. This avoids creating
  a parallel text view and ensures `drawBackground(in:)` runs on the real subclass.
- **`isPrint` flag on the builder.** Tables emit invisible (clear foreground) inline
  text on screen because `TableBlockView` overlays handle display. During print,
  `isPrint: true` makes table text visible with proper foreground colors since no
  overlay exists.
- **`NSPrintOperation.current` guard on table drawing.** The `drawTableContainers`
  method is a no-op on screen, activating only during print to avoid drawing
  duplicate table chrome behind the SwiftUI overlay.
- **WCAG AA contrast.** Every syntax color meets a 4.5:1 minimum contrast ratio
  against white. Comments are intentionally lighter than keywords.

## Files

| File | Role |
|------|------|
| `mkdn/UI/Theme/PrintPalette.swift` | Static print color palette (ThemeColors + SyntaxColors) |
| `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` | `printBlocks` property, `printView(_:)` override (save/rebuild/print/restore) |
| `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+TablePrint.swift` | Print-time table container drawing (border, header, rows, divider) |
| `mkdn/Features/Viewer/Views/SelectableTextView.swift` | Plumbs `blocks` to `textView.printBlocks` in `makeNSView`/`updateNSView` |
| `mkdn/App/MkdnCommands.swift` | File > Print menu item dispatching `printView(_:)`, Page Setup dispatching `runPageLayout(_:)` |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` | `build(blocks:colors:syntaxColors:isPrint:)` overload accepting explicit palette |
| `mkdn/Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift` | `isPrint` flag controls table text foreground visibility |

## Dependencies

- **Internal:** `ThemeColors`, `SyntaxColors`, `CodeBlockColorInfo`, `TableColorInfo`,
  `TableCellMap`, `CodeBlockAttributes`, `TableAttributes`,
  `MarkdownTextStorageBuilder`, `PlatformTypeConverter`.
- **External:** AppKit print infrastructure (`NSPrintOperation`, `NSPrintInfo`).
  No new third-party dependencies.

## Testing

| Test File | Coverage |
|-----------|----------|
| `mkdnTests/Unit/Core/PrintPaletteTests.swift` | Background is white, foreground is black, headings black, all ThemeColors/SyntaxColors fields populated, differs from both Solarized themes, code background is light gray, link color is dark blue, WCAG AA contrast for all 8 syntax token colors, comment de-emphasis vs keyword |
| `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTests+PrintPalette.swift` | Explicit-colors overload produces valid string, theme-based build matches explicit-colors build, code block `CodeBlockColorInfo` embeds print palette background and border |
