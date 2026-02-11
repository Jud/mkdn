# Quick Build: Fix Link Cursor

**Created**: 2026-02-10T12:00:00Z
**Request**: test links don't show a hand cursor -- they don't look clickable
**Scope**: Small

## Plan

**Reasoning**: 1-2 files affected (CodeBlockBackgroundTextView.swift is the NSTextView subclass, SelectableTextView.swift may need minor delegate wiring), 1 system (Viewer), low risk -- purely visual cursor feedback with no logic changes.

**Files Affected**:
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` -- override `resetCursorRects` to add pointing-hand cursor rects over link ranges
- `mkdn/Features/Viewer/Views/SelectableTextView.swift` -- possibly set `linkTextAttributes` to ensure link styling is preserved (currently handled by attributed string, but NSTextView may override)

**Approach**: Override `resetCursorRects` in `CodeBlockBackgroundTextView` (the NSTextView subclass used in the preview pane) to enumerate `.link` attributes in the text storage, compute their bounding rects via the TextKit 2 layout manager, and add `NSCursor.pointingHand` cursor rects for each link range. This is the standard AppKit pattern for showing a hand cursor over links in a non-editable NSTextView. Additionally, ensure `linkTextAttributes` on the text view includes the theme's link color and underline style so the system does not override the builder's styling.

**Estimated Effort**: 0.5-1 hours

## Tasks

- [x] **T1**: Override `resetCursorRects` in `CodeBlockBackgroundTextView` to enumerate `.link` attributes in `textStorage`, compute glyph bounding rects via TextKit 2 layout fragments, and call `addCursorRect(_:cursor:)` with `NSCursor.pointingHand` for each link rect `[complexity:medium]`
- [x] **T2**: In `SelectableTextView.configureTextView`, set `linkTextAttributes` on the NSTextView to match the theme's link color and underline style so the system's default link appearance does not override the builder's attributed string styling `[complexity:simple]`
- [x] **T3**: Verify that `resetCursorRects` is called on content updates by ensuring `invalidateCursorRects(for:)` is triggered when `textStorage` changes (NSTextView normally handles this, but confirm with a manual test) `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` | Added `resetCursorRects` override that enumerates `.link` attributes, computes fragment frames via TextKit 2 layout manager, and adds `NSCursor.pointingHand` cursor rects for each link range | Done |
| T2 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | Set `linkTextAttributes` in `applyTheme` (not static `configureTextView`, since link color depends on theme) with foreground color, underline, and pointingHand cursor | Done |
| T3 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | Added `textView.window?.invalidateCursorRects(for: textView)` after `setAttributedString` in both `makeNSView` and `updateNSView` to ensure cursor rects refresh on content changes | Done |

## Verification

{To be added by task-reviewer if --review flag used}
