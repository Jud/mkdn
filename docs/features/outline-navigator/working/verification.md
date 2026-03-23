# Verification Report: Document Outline Navigator

**Status:** Pass
**Date:** 2026-03-21
**Round:** 1

## Summary

The specification is well-structured, internally consistent, and thoroughly researched. All new components have defined locations, responsibilities, and interfaces. The design correctly leverages existing codebase patterns (FindBar overlay, OverlayCoordinator scroll observation, stateless enum builders). Four minor findings identified; none block implementation.

## Findings

### Finding 1: Scroll-spy block index mapping mechanism underspecified
**Severity:** Minor
**Location:** architecture.md, "Modified Components" section 6 (SelectableTextView+Coordinator)
**Issue:** The architecture says the Coordinator needs "logic to map the scroll position (y offset) to the current heading block index using the text layout manager" but does not specify *how* this mapping works. The heading `blockIndex` is a sequential offset in the `[IndexedBlock]` array, but the text layout manager works with character ranges/rects, not block indices. The implementer must: (1) maintain a mapping from block indices to character ranges (built during `MarkdownTextStorageBuilder.build()`), or (2) scan `NSTextLayoutManager` fragments to find which heading's character range is at the viewport top. Neither approach is spelled out.
**Why it matters:** This is the most technically novel part of the feature and the one with the highest implementation risk (assumptions A1 and A2 are "accepted-risk"). An implementer could lose time figuring out the mapping strategy. However, the worklog explicitly flags this as a Phase 3 validation item, and the approach is fundamentally sound -- the existing `OverlayCoordinator` already performs similar fragment-to-position mapping for table overlays.
**Suggested fix:** Add a "Scroll-spy mapping strategy" note in the Coordinator modification section explaining that the implementer should use the same `NSTextLayoutManager.enumerateTextLayoutFragments` approach used by `OverlayCoordinator+Positioning`, scanning from the viewport top to find the first heading fragment.

### Finding 2: MkdnCommands code shows `showHUD()` but Cmd+J should toggle
**Severity:** Minor
**Location:** architecture.md, "Modified Components" section 3 (MkdnCommands)
**Issue:** The code snippet shows `outlineState?.showHUD()` but the PRD's keyboard interaction table (prd.md, "Keyboard Interaction") says Cmd+J should "Toggle outline HUD." If the HUD is already open, pressing Cmd+J should dismiss it, not be a no-op.
**Why it matters:** Minor UX inconsistency. The implementer would likely notice and implement toggle behavior, but the spec code and the PRD text disagree.
**Suggested fix:** Change the `MkdnCommands` snippet to call a `toggleHUD()` method (or check `isHUDVisible` and conditionally call `showHUD()`/`dismissHUD()`). Add `toggleHUD()` to the `OutlineState` interface.

### Finding 3: No cross-reference dependency marker on Coordinator modification
**Severity:** Minor
**Location:** architecture.md, "Modified Components" section 6 (SelectableTextView+Coordinator)
**Issue:** The section has a cross-reference marker linking back to FR-9 through FR-11, which is correct. However, the same section should also cross-reference the "Scroll-spy mapping strategy" that feeds into Flow 2 (Scroll -> Breadcrumb Update). Flow 2 step 4 says "Coordinator maps y-position to the nearest heading block index via text layout manager" -- if the Coordinator implementation changes, Flow 2 must also be updated.
**Why it matters:** Low risk since the flow diagram is descriptive rather than prescriptive, but the cross-reference pattern used elsewhere in the docs should be applied consistently.
**Suggested fix:** Add Flow 2 to the cross-reference list on section 6.

### Finding 4: HeadingNode uses UUID for `id` -- unnecessary allocation
**Severity:** Minor
**Location:** architecture.md, "Component Design" section 1 (HeadingNode)
**Issue:** `HeadingNode` uses `UUID()` for its `Identifiable.id`, but `blockIndex` is already unique per heading within a document and is an `Int`. Using `blockIndex` as the `id` would avoid UUID allocation and make identity semantically meaningful (matching the block's position in the document).
**Why it matters:** Not a correctness issue, but UUID allocation for a transient, frequently-rebuilt data structure is wasteful. More importantly, using `blockIndex` as `id` would make SwiftUI diffing more efficient when the heading tree is rebuilt (same headings at same positions would be recognized as identical).
**Suggested fix:** Consider using `blockIndex` as the `Identifiable.id`, or a composite of `(level, blockIndex)` if uniqueness across tree rebuilds is needed.

## Implicit Assumptions Discovered

- **The text layout manager completes layout synchronously before scroll-spy queries it.** The architecture assumes that when a `boundsDidChangeNotification` fires, the layout manager has already laid out the heading fragments and can return their positions. In practice, TextKit 2 uses lazy layout, and fragments may not be enumerable until they've been in the viewport. Found in: architecture.md, Flow 2 step 4. Mitigated by the error handling table entry ("Text layout not ready during scroll-spy: skip update, wait for next scroll event"), but this assumption should be in the Assumptions Register.

- **Heading text extraction via `String(text.characters)` produces usable display text.** The `MarkdownBlock.heading` carries an `AttributedString`, and the architecture says HeadingNode uses "plain `String` title (stripped from `AttributedString`)." This works via `String(attributedString.characters)`, which is the pattern already used in `MarkdownBlock.id`. Found in: architecture.md, HeadingNode design notes. This is low-risk since the pattern is proven in the codebase.

## Verification Checklist Results

| Area | Status | Notes |
|------|--------|-------|
| Internal consistency | Pass | PRD requirements map cleanly to architecture components. Naming is consistent. Only minor toggle vs. show inconsistency (Finding 2). |
| Completeness | Pass | All new components have location, responsibility, and interface. Modified components have specific changes described. Error handling covers the key failure modes. |
| Feasibility | Pass | All proposed APIs are verified against the actual codebase. `boundsDidChangeNotification` is already used by `OverlayCoordinator`. `scrollRangeToVisible` is already used in the Coordinator. LOC estimates are reasonable. Phase ordering is viable -- each phase builds on the previous with no circular dependencies. |
| Implicit assumptions | Pass | Two implicit assumptions found but both are low-risk and partially mitigated. The Assumptions Register already captures the two highest-risk items (A1, A2). |
| Evidence coverage | Pass | Four research files with real code evidence (file paths, line numbers, code snippets). All footnote references resolve to evidence files. Evidence contains actual source code, not restated claims. |
| Hand-waving detection | Pass | No TBD/TODO items. No "handle appropriately" language. Fuzzy matching semantics are specified concretely (fzf-style, characters in order). Error recovery strategies are concrete (clamp, skip, disable). |
| Security & safety | Pass | No security surface -- feature reads from in-memory parsed data, performs no I/O or network access. No new trust boundaries. No data loss risk (read-only navigation). |
| Codebase alignment | Pass | All referenced files exist at stated paths. Line numbers match (MarkdownBlock.swift:23 for heading case, IndexedBlock at :78). Proposed modifications align with current code structure. `FindState` pattern (@@MainActor @Observable, @State in DocumentWindow, environment injection, focusedSceneValue) is accurately described. |

## Assumptions Review
**Status:** Assumptions Accepted
**Date:** 2026-03-21
