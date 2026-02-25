# Find in Page

## Overview

A custom pill-shaped find bar replaces the stock NSTextFinder with a compact overlay that matches mkdn's Solarized design language. It floats in the top-right corner of the preview viewport without displacing content, providing live incremental search, match highlighting via TextKit 2 rendering attributes, and full keyboard-driven navigation. The find bar operates on the rendered preview text only -- Mermaid diagrams (WKWebView) and images are out of scope.

## User Experience

The find bar activates with Cmd+F and appears as a 300pt-wide frosted glass pill (`.ultraThinMaterial`, Capsule clip) at the top-right of the preview. The entrance animation is a scale+fade (0.95/0 to 1.0/1.0) using `springSettle`; exit uses `quickFade`. Both degrade to `reducedInstant` under Reduce Motion.

Layout within the pill, left to right: magnifying glass icon, plain text field, "N of M" match count (or "No matches"), previous/next chevron buttons, close (xmark) button. All icons use `.secondary` foreground style for legibility across both Solarized themes.

Keyboard contract:
- **Cmd+F** -- Show find bar (or re-focus if already visible)
- **Return / Cmd+G** -- Next match
- **Shift+Return / Cmd+Shift+G** -- Previous match
- **Cmd+E** -- Use selection for find (populates and shows the bar)
- **Escape** -- Dismiss find bar, clear highlights, return focus to text view

Search is always case-insensitive. Navigation wraps in both directions.

## Architecture

The feature follows the existing per-window state pattern. `FindState` is an `@Observable` model created in `DocumentWindow` and injected into the environment alongside `DocumentState`. Menu commands reach the active window's `FindState` through a `FocusedValueKey`.

Data flow:
1. User types in `FindBarView` -- updates `FindState.query`.
2. SwiftUI calls `updateNSView` on `SelectableTextView` (query is a value parameter).
3. The Coordinator calls `FindState.performSearch(in:)` against `textStorage.string`.
4. Coordinator applies TextKit 2 rendering attributes: accent color at 0.15 alpha for all matches, 0.4 alpha for the current match.
5. Coordinator calls `scrollRangeToVisible` for the current match.
6. `FindBarView` observes updated `matchRanges`/`currentMatchIndex` and renders the count.

The find bar sits at the highest z-order in `ContentView`'s ZStack, above Mermaid overlays, table overlays, code block copy buttons, and the mode transition overlay.

## Implementation Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State model | Dedicated `FindState` (not embedded in `DocumentState`) | Single responsibility; avoids bloating the document model |
| Search execution | Coordinator calls `performSearch` in `updateNSView` | Coordinator owns access to `textStorage`; avoids `didSet` chains |
| Highlight mechanism | TextKit 2 `setRenderingAttributes` | Visual-only; does not mutate text storage or attributed string |
| NSTextFinder | Fully removed (not coexisting) | Avoids conflicting highlight/focus behavior |
| Menu integration | `FocusedValueKey` pattern | Matches existing `FocusedDocumentStateKey` convention |
| Animation primitives | `springSettle` / `quickFade` / `reducedInstant` | Named constants from `AnimationConstants`; no ad hoc values |
| Material | `.ultraThinMaterial` | Consistent with `CodeBlockCopyButton` and other overlay surfaces |

## Files

**New files:**
- `mkdn/Features/Viewer/ViewModels/FindState.swift` -- Per-window observable: query, visibility, match ranges, search logic, navigation with wrap-around.
- `mkdn/Features/Viewer/Views/FindBarView.swift` -- SwiftUI pill UI: text field, match count label, chevron nav buttons, close button, keyboard handling.
- `mkdn/App/FocusedFindStateKey.swift` -- `FocusedValueKey` bridging `FindState` to menu commands.

**Modified files:**
- `mkdn/Features/Viewer/Views/SelectableTextView.swift` -- Accepts find parameters; Coordinator applies rendering attributes and scroll-to-match; NSTextFinder config removed.
- `mkdn/App/ContentView.swift` -- Adds `FindBarView` overlay at highest z-order.
- `mkdn/App/MkdnCommands.swift` -- Replaces `sendFindAction` / `performFindPanelAction` with `FindState` dispatch via `@FocusedValue`.
- `mkdn/App/DocumentWindow.swift` -- Creates `FindState` instance; injects via `.environment()` and `.focusedSceneValue()`.
- `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` -- Reads `FindState` from environment; passes find parameters to `SelectableTextView`.

## Dependencies

| Dependency | Type | Usage |
|------------|------|-------|
| `AnimationConstants` (springSettle, quickFade, reducedInstant) | Existing | Entrance/exit animations |
| `MotionPreference` | Existing | Reduce Motion compliance |
| `ThemeColors.accent` | Existing | Match highlight color derivation |
| `.ultraThinMaterial` | SwiftUI API | Frosted glass background |
| TextKit 2 `NSTextLayoutManager.setRenderingAttributes` | AppKit API | Visual-only match highlights |
| `NSTextView.scrollRangeToVisible` | AppKit API | Scroll to current match |

No new external packages. Everything builds with the existing dependency graph.

## Testing

**Unit tests** (`mkdnTests/Unit/Features/FindStateTests.swift`, 15 tests):
- Search: empty query produces no matches; case-insensitive matching; multiple match ranges with correct locations; no-match case.
- Navigation: sequential next/previous; forward wrap (last to first); backward wrap (first to last); no-op when zero matches.
- Lifecycle: `dismiss()` clears all state; `show()` sets visibility; `useSelection()` populates query and shows bar.
- Content change: re-search recomputes matches; `currentMatchIndex` clamped when match count decreases; index resets to zero when all matches disappear.

All tests operate directly on the `FindState` model with no AppKit or UI dependencies.

**Visual verification**: Highlight rendering, scroll-to-match behavior, frosted glass appearance, and theme adaptation are verified through the mkdn-ctl visual testing workflow (load fixture, capture screenshots in both Solarized themes, inspect at multiple scroll positions).
