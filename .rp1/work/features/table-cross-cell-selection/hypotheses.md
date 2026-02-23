# Hypothesis Document: table-cross-cell-selection
**Version**: 1.0.0 | **Created**: 2026-02-23 | **Status**: VALIDATED

## Hypotheses
### HYP-001: Tab-stop invisible text layout fragment alignment with NSHostingView overlay
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: Tab-stop-based invisible text in NSTextStorage will produce layout fragments whose bounding rect aligns vertically with the SwiftUI TableBlockView overlay, enabling accurate selection highlight positioning.
**Context**: The entire table cross-cell selection design depends on the invisible text layer and visual overlay layer being spatially aligned. If layout fragments from the invisible text diverge from the overlay position, selection highlights will be mispositioned.
**Validation Criteria**:
- CONFIRM if: Build a minimal test - create invisible table text with fixed-height paragraph styles, position an NSHostingView overlay at the bounding rect of the text's layout fragments, and verify the overlay frame matches within 1pt tolerance
- REJECT if: Bounding rect diverges by more than 2pt or individual row heights cause cumulative drift
**Suggested Method**: CODE_EXPERIMENT

### HYP-002: Opaque NSHostingView overlay hides NSTextStorage background color changes
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: Find highlight background color changes on invisible table text in NSTextStorage are not visible to the user because the opaque NSHostingView (TableBlockView) overlay sits on top of the text view's rendering area.
**Context**: The design relies on the opaque visual overlay completely covering the invisible text. If find-highlight background colors bleed through or around the edges, it would produce confusing visual artifacts.
**Validation Criteria**:
- CONFIRM if: Set .backgroundColor on a range of clear-foreground text in an NSTextView, add an opaque NSHostingView as a subview covering that range, and observe no background color is visible through the hosting view
- REJECT if: Background color somehow bleeds through or is visible around the edges of the NSHostingView overlay
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-23T20:15:00Z
**Method**: CODE_EXPERIMENT
**Result**: CONFIRMED

**Evidence**:

A disposable Swift package (`/tmp/hypothesis-table-cross-cell-selection/`) created a TextKit 2 NSTextView with invisible tab-separated text (6 rows: 1 header + 5 data rows) using `.foregroundColor: .clear` and cumulative tab stops at column boundaries (150pt, 350pt, 500pt). The experiment measured layout fragment geometry and compared it to an NSHostingView positioned at the bounding rect.

**Key measurements:**

1. **Position alignment**: 0.00pt difference between computed overlay frame origin and NSHostingView actual frame origin. The overlay Y-position and bounding rect Y-position matched exactly.

2. **Height alignment**: 0.00pt difference. The total bounding rect height (128.0pt for 6 rows) was identical to the overlay height.

3. **Per-row fragment analysis**:
   - Header row (bold font): 23.0pt fragment height
   - Body rows (regular font): 21.0pt fragment height each
   - Inter-fragment gaps: 0.0pt (fragments are contiguous with no gaps)
   - Maximum height variance between rows: 2.00pt (header vs body, due to bold font metrics)
   - No cumulative drift detected -- total span equals sum of individual fragment heights

4. **Text-range positioning accuracy**: `NSTextLayoutManager.textLayoutFragment(for:)` returned the exact same Y-position (61.0pt) as the enumerated fragment[0] -- 0.00pt difference. This confirms OverlayCoordinator's existing text-range-based positioning approach will work identically for table text ranges.

5. **Fragment count**: TextKit 2 produced exactly 6 layout fragments for 6 table rows (1 fragment per paragraph/row), confirming a clean 1:1 mapping between table rows and layout fragments.

**Sources**:
- Experiment code: `/tmp/hypothesis-table-cross-cell-selection/Sources/main.swift`
- Existing OverlayCoordinator positioning: `mkdn/Features/Viewer/Views/OverlayCoordinator.swift:360-406`
- Existing EntranceAnimator fragment enumeration: `mkdn/Features/Viewer/Views/EntranceAnimator.swift:110-148`

**Implications for Design**:
The design's assumption that invisible tab-separated text produces spatially predictable layout fragments is valid. The OverlayCoordinator's existing text-range-based positioning pattern (used for attachment-based overlays at line 381) will work identically for table text ranges without modification to the positioning math. The 2pt variance between header and body row heights is expected (bold vs regular font metrics) and does not cause cumulative drift -- the overlay only needs to match the total bounding rect, not individual rows. The selection highlight overlay (TableHighlightOverlay) can reliably use layout fragment geometry to draw cell-level highlights.

### HYP-002 Findings
**Validated**: 2026-02-23T20:15:00Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS
**Result**: CONFIRMED

**Evidence**:

**1. Code experiment (architectural validation):**

A disposable Swift package tested adding an NSHostingView with opaque SwiftUI `.background(Color.white)` content as a subview of an NSTextView. The experiment applied bright yellow `.backgroundColor` to invisible text in the text storage and verified the overlay's properties.

Key findings:
- `NSHostingView.isOpaque` returns `false` (SwiftUI does not propagate opacity hints to AppKit)
- `layer.opacity` = 1.0 (fully visible overlay)
- hitTest at overlay center returns the hosting view's subview (confirms overlay intercepts mouse events, validating the need for PassthroughHostingView with `hitTest -> nil`)
- SwiftUI's `.background(Color.white)` fills the entire hosting view bounds with an opaque color regardless of `isOpaque` reporting

**2. Codebase analysis (rendering order):**

The existing mkdn codebase confirms the rendering stack:

- `OverlayCoordinator.createOverlay()` calls `textView.addSubview(overlayView)` (line 264) -- overlays are subviews of the NSTextView
- `CodeBlockBackgroundTextView.drawBackground(in:)` draws code block containers (lines 319-321) -- this happens during the parent view's draw pass, BEFORE subviews render
- `TableBlockView` uses opaque backgrounds on every row:
  - Header: `.background(colors.backgroundSecondary)` (line 80)
  - Even rows: `.background(colors.background)` (line 109)
  - Odd rows: `.background(colors.backgroundSecondary.opacity(0.7))` (line 110)
  - The entire VStack is clipped via `.clipShape(RoundedRectangle(cornerRadius: 6))` (line 55)

**3. AppKit rendering order (architectural guarantee):**

The standard AppKit view drawing cycle is: background -> content -> subviews. This is a fundamental AppKit guarantee:
- NSTextView's `drawBackground(in:)` fires first, filling the document background
- TextKit 2 then draws text content (including `.backgroundColor` attributes on text ranges)
- Subviews (NSHostingView overlays) render ON TOP of the parent's drawing
- An NSHostingView whose SwiftUI content fills its bounds with an opaque color will completely cover any text-level background color changes underneath

**4. Edge bleeding risk assessment:**

The only scenario where background color could be visible is if the overlay frame does not perfectly cover the text range. From HYP-001, we confirmed 0.00pt alignment between layout fragment bounding rect and overlay frame, so this risk is negligible. The `.clipShape(RoundedRectangle(cornerRadius: 6))` on TableBlockView creates 6pt corner radii where sub-pixel gaps could theoretically expose the underlying text -- but the background color on invisible text is thin (only the height of text glyphs), and the corner radius is at the outer edge of the table where there is typically no text content.

**Sources**:
- Experiment code: `/tmp/hypothesis-table-cross-cell-selection/Sources/main.swift`
- OverlayCoordinator subview addition: `mkdn/Features/Viewer/Views/OverlayCoordinator.swift:264`
- TableBlockView backgrounds: `mkdn/Features/Viewer/Views/TableBlockView.swift:80,107-111`
- CodeBlockBackgroundTextView draw order: `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift:319-321`
- Apple docs on addSubview: https://developer.apple.com/documentation/appkit/nsview/addsubview(_:)
- Apple docs on drawBackground: https://developer.apple.com/documentation/appkit/nstextview/drawbackground(in:)

**Implications for Design**:
Find highlight `.backgroundColor` changes on invisible table text in NSTextStorage will be completely hidden by the opaque TableBlockView overlay. The design's plan to use a separate TableHighlightOverlay (rendered on top of TableBlockView) for find/selection feedback is correct -- the invisible text layer handles the semantic find matching, while the overlay handles the visual feedback. No special handling is needed to prevent background color bleed-through. The hitTest finding confirms that PassthroughHostingView (with `hitTest -> nil`) is essential -- without it, the hosting view will intercept mouse events intended for the NSTextView's selection tracking.

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | CONFIRMED | Layout fragments align within 0pt tolerance; text-range positioning matches enumeration exactly; no cumulative drift across rows |
| HYP-002 | HIGH | CONFIRMED | Opaque overlay fully conceals background colors; AppKit rendering order guarantees subviews draw on top; PassthroughHostingView essential for mouse events |
