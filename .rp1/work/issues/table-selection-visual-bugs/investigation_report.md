# Root Cause Investigation Report - table-selection-visual-bugs

## Executive Summary
- **Problem**: When selecting text across a table in the mkdn viewer, the "invisible" table text becomes visible, the native blue selection highlight bleeds past table boundaries, and the custom cell-level TableHighlightOverlay is not visually effective because the native selection rendering dominates.
- **Root Cause**: NSTextView's `selectedTextAttributes` mechanism overrides the clear foreground color on selected text, making invisible table text visible. The native selection highlight rect is drawn beneath the table overlay stack but above the text, and nothing in the current code suppresses it within table regions.
- **Solution**: Override `drawInsertionPoint(in:color:turnedOn:)` is not sufficient -- the real fix requires overriding the TextKit 2 selection rendering in `CodeBlockBackgroundTextView` to suppress both the selection background fill and the foreground color override for text ranges that carry `TableAttributes.range`.
- **Urgency**: Medium -- the feature is functionally correct (copy, find, select-all work), but the visual bugs undermine the dual-layer rendering design.

## Investigation Process
- **Duration**: Single-pass investigation
- **Hypotheses Tested**: 4 (all confirmed to varying degrees; hypotheses 1 and 4 are the primary root causes)
- **Key Evidence**: (1) `selectedTextAttributes` includes `.foregroundColor: fgColor` which overrides `.clear` on selected text, (2) No override exists in `CodeBlockBackgroundTextView` to suppress native selection drawing in table regions, (3) The TableHighlightOverlay IS correctly positioned and receives cell data, but the native selection rendering underneath it makes it invisible/redundant.

## Root Cause Analysis

### Root Cause 1: `selectedTextAttributes` Overrides Clear Foreground Color

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`, lines 213-216

```swift
textView.selectedTextAttributes = [
    .backgroundColor: accentColor.withAlphaComponent(0.3),
    .foregroundColor: fgColor,
]
```

When the user selects text, NSTextView applies `selectedTextAttributes` to the visual rendering of all selected characters. This dictionary explicitly sets `.foregroundColor` to `fgColor` (the theme's foreground color -- a visible, opaque color). For table text, the original `.foregroundColor` is `.clear` (set in `MarkdownTextStorageBuilder+TableInline.swift` line 88 and 108), but during selection NSTextView replaces it with the theme foreground from `selectedTextAttributes`.

This is the direct cause of **Bug 1**: invisible text leaking. The tab-separated cell content (e.g., "Main document view...") becomes visible because its foreground is changed from `.clear` to the theme foreground during selection.

### Root Cause 2: Native Selection Background Rect Not Suppressed for Table Regions

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`

The `CodeBlockBackgroundTextView` subclass overrides `drawBackground(in:)` (line 324) to draw code block containers and table print containers, but it does **not** override the selection drawing phase. In TextKit 2, the selection background is drawn by the framework as part of the text rendering pipeline, and the `selectedTextAttributes[.backgroundColor]` (accent at 0.3 alpha) is applied to all selected text -- including table text.

The rendering stack for a table region during selection is:

1. `drawBackground(in:)` -- document background + code block containers + table print containers
2. TextKit 2 text rendering -- draws characters (table text is `.clear` foreground, so invisible here)
3. **TextKit 2 selection rendering** -- draws selection background rect AND overrides foreground color using `selectedTextAttributes`
4. TableBlockView overlay (NSHostingView) -- sits on top as a subview
5. TableHighlightOverlay -- sits on top as a subview

The problem: Step 3 draws the selection highlight at the NSTextView text layer level. This appears **under** the TableBlockView overlay (step 4), but because the table overlay does not cover the entire layout fragment region (especially trailing newlines and paragraph spacing), the native selection rect "bleeds" past the table's visual boundary -- **Bug 2**.

Additionally, the foreground color override at step 3 causes characters to render in the theme foreground color, which IS visible and draws underneath the table overlay -- **Bug 1** again. Even though the TableBlockView covers most of the area, any pixel-level misalignment or sub-pixel rendering means the visible text shows through.

### Root Cause 3: TableHighlightOverlay Works But Is Visually Redundant

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator+TableOverlays.swift`, lines 42-73

The `updateTableSelections` method correctly maps the NSTextView selection range to cell positions via `cellMap.cellsInRange()` and updates the `TableHighlightOverlay`. The overlay IS drawing cell-level highlights on top of the TableBlockView. However, the native NSTextView selection rendering underneath creates a "double highlight" effect -- the native selection rect at step 3 AND the overlay highlight at step 5. The native selection is the dominant visual because:

- It applies to the FULL text range including tabs and newlines (extending to line edges)
- It overrides the foreground color making invisible text visible
- Its geometry follows text layout fragment rects, not cell boundaries

This explains **Bug 3**: the selection doesn't align with cell boundaries. The user sees the native text-level selection (which follows text layout geometry) rather than the cell-level TableHighlightOverlay (which follows table cell geometry).

### Causation Chain

```
Root Cause: selectedTextAttributes includes .foregroundColor override
    |
    v
NSTextView selection rendering applies .foregroundColor: fgColor to selected table text
    |
    v
Table text (originally .clear foreground) renders in visible theme foreground color
    |
    +---> Bug 1: "invisible" text becomes visible during selection
    |
    v
NSTextView selection rendering applies .backgroundColor to full text layout fragments
    |
    +---> Bug 2: selection rect extends beyond table visual boundary (into trailing newlines/paragraph spacing)
    |
    v
Native selection rect dominates over TableHighlightOverlay drawing
    |
    +---> Bug 3: selection appears as text-level highlight, not cell-level highlight
```

### Why It Occurred

The design document (`design.md` section 3.6, layer diagram) correctly identified this risk:

> **4. NSTextView Selection (hidden under overlay)**

The assumption was that the TableBlockView overlay (layer 5) and TableHighlightOverlay (layer 6) would visually hide the native NSTextView selection (layer 4). However, this assumption fails because:

1. **Foreground color override**: `selectedTextAttributes[.foregroundColor]` causes text to render visibly BEFORE the overlay is drawn. NSTextView renders selected text with the override color, which is visible even at the text rendering layer (step 2/3 in the stack).

2. **Geometric mismatch**: The native selection rect follows text layout fragment geometry (full-width paragraphs), while the TableBlockView overlay has specific table width. Any area outside the overlay's bounds shows the native selection.

3. **Sub-pixel rendering**: Even within the overlay's bounds, macOS text rendering with a visible foreground color may produce sub-pixel anti-aliased glyphs that "bleed through" the overlay boundaries.

## Proposed Solutions

### Solution 1 (Recommended): Suppress Native Selection Rendering for Table Regions

**Effort**: Medium (1-2 hours)
**Risk**: Low -- targeted override in existing NSTextView subclass

The `CodeBlockBackgroundTextView` subclass should intercept the selection rendering pipeline for table regions. There are two complementary approaches:

**A. Override `setSelectedRanges(_:affinity:stillSelecting:)` to exclude table ranges from `selectedTextAttributes`**

Before calling `super`, modify the text storage to temporarily set a custom selection appearance for table regions:

```swift
override func setSelectedRanges(
    _ ranges: [NSValue],
    affinity: NSSelectionAffinity,
    stillSelecting: Bool
) {
    super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
}
```

This alone does not help. The key insight is:

**B. Make `selectedTextAttributes` NOT override foreground color, and instead suppress selection background drawing for table regions**

Option B1: Remove `.foregroundColor` from `selectedTextAttributes` entirely. This prevents the invisible text from becoming visible during selection. The selection background color (accent at 0.3) will still draw, but since the text remains `.clear`, the user won't see the raw text content. The selection background rect under the table overlay is less visually disruptive than visible text.

```swift
// In SelectableTextView.applyTheme:
textView.selectedTextAttributes = [
    .backgroundColor: accentColor.withAlphaComponent(0.3),
    // Remove .foregroundColor -- let the original foreground color be used
]
```

**Impact**: This fixes Bug 1 immediately. Normal non-table text will render with its original foreground during selection (which is already the correct theme foreground), so there's no visual regression for non-table text.

However, this still leaves the selection background rect visible underneath table overlays (Bugs 2 and 3).

Option B2: Override `drawInsertionPoint(in:color:turnedOn:)` -- this only affects the insertion point cursor, not selection highlighting. NOT useful.

Option B3: Use a custom `NSTextLayoutManager` delegate or `NSTextLayoutFragment` subclass to suppress selection decoration for table ranges. This is the most correct approach but is complex in TextKit 2.

**C. Override selection drawing via `NSLayoutManager` or TextKit 2 equivalent**

In TextKit 2 (which this codebase uses), selection rendering is handled internally by the `NSTextLayoutManager`. The documented way to customize it is through the `NSTextViewDelegate` method `textView(_:willDisplayToolTip:forCharacterAt:)` -- but this is for tooltips, not selection.

The pragmatic approach: Override the drawing pipeline to paint over the native selection in table regions:

```swift
// In CodeBlockBackgroundTextView
override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    // After super draws everything (including selection),
    // repaint table regions with the background color to
    // suppress native selection rendering.
    suppressTableSelectionRendering(in: dirtyRect)
}
```

Where `suppressTableSelectionRendering` enumerates `TableAttributes.range` regions, computes their bounding rects, and fills them with the document background color. This effectively "erases" the native selection in table areas. The TableBlockView overlay and TableHighlightOverlay then draw on top cleanly.

**Recommended combined approach**:

1. Remove `.foregroundColor` from `selectedTextAttributes` (fixes Bug 1, no regression for non-table text)
2. In `CodeBlockBackgroundTextView.draw(_:)`, after `super.draw(dirtyRect)`, repaint table bounding rects with background color (fixes Bugs 2 and 3)
3. The existing TableHighlightOverlay already handles cell-level selection drawing correctly

### Solution 2 (Alternative): Use Zero-Alpha Selection for Table Ranges via NSTextContentStorageDelegate

**Effort**: High (3-4 hours)
**Risk**: Medium -- requires understanding of TextKit 2 content storage delegate lifecycle

Implement `NSTextContentStorageDelegate` or override `NSTextContentStorage.textContentStorage(_:textParagraphWith:)` to provide custom `NSTextLayoutFragment` instances for table ranges that suppress selection rendering attributes.

**Pros**: Most architecturally correct; doesn't require post-hoc drawing cleanup.
**Cons**: TextKit 2's documentation for customizing selection rendering is sparse; may introduce layout side-effects.

### Solution 3 (Alternative): Move Table Overlay to a Separate Layer Above Selection

**Effort**: Medium (2-3 hours)
**Risk**: Medium -- z-order management complexity

Instead of adding the TableBlockView and TableHighlightOverlay as NSTextView subviews (which are in the NSTextView's view hierarchy and can be affected by text rendering), host them in a separate transparent NSView that is a sibling of the NSTextView but positioned above it via `addSubview(_:positioned:.above)`.

**Pros**: Completely separates visual table from NSTextView's rendering pipeline.
**Cons**: Requires careful scroll/layout synchronization; overlays would no longer receive NSTextView's scroll events natively.

## Prevention Measures

1. **Visual testing for selection**: Add a visual test that loads a table fixture, simulates selection across the table, captures a screenshot, and verifies the invisible text is not visible. This would catch regressions.

2. **Design review for dual-layer rendering**: When implementing invisible-text patterns, always verify that `selectedTextAttributes` does not override the hidden foreground color. Document this interaction in the architecture knowledge base.

3. **Integration test for selection attributes**: Add a unit test that verifies `selectedTextAttributes` does not include `.foregroundColor` when the document contains tables, or that the foreground override does not affect `.clear`-colored text.

## Evidence Appendix

### Evidence 1: selectedTextAttributes Foreground Override
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`, lines 213-216
```swift
textView.selectedTextAttributes = [
    .backgroundColor: accentColor.withAlphaComponent(0.3),
    .foregroundColor: fgColor,   // <-- THIS overrides .clear on table text
]
```

### Evidence 2: Table Text Uses .clear Foreground
File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift`, lines 88 and 108
```swift
let headerForeground: NSColor = isPrint ? colorInfo.headingColor : .clear
// ...
let dataForeground: NSColor = isPrint ? colorInfo.foreground : .clear
```

### Evidence 3: No Selection Drawing Override in NSTextView Subclass
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`
The class overrides `drawBackground(in:)` and `draw(_:)` but does NOT override any selection-related drawing methods. There is no mechanism to suppress or customize native selection rendering for specific text ranges.

### Evidence 4: TableHighlightOverlay Is Correctly Wired
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator+TableOverlays.swift`, lines 42-73
`updateTableSelections` correctly maps selection ranges to cell positions and updates the overlay. The overlay IS drawing. But the native selection underneath it creates visual competition.

### Evidence 5: Design Acknowledged But Didn't Resolve the Layer Conflict
File: `/Users/jud/Projects/mkdn/.rp1/work/features/table-cross-cell-selection/design.md`, section 2.1
The design diagram shows "4. NSTextView Selection (hidden under overlay)" -- the assumption was that the overlay would hide the native selection. This assumption is incorrect because NSTextView's `selectedTextAttributes[.foregroundColor]` operates at the text rendering level, before overlays are composited.
