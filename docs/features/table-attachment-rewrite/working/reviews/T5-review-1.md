# Code Review: T5 -- Cleanup: delete obsolete table infrastructure

**Date:** 2026-03-24
**Round:** 1
**Verdict:** pass

## Summary

Clean deletion of 11 source files and 2 test files, with 8 source files and 1 test file correctly stripped of all table-range-based code paths. The new `MarkdownTextStorageBuilder+TablePrint.swift` is a well-structured replacement for the deleted inline-text print path. One dead function left behind (`makeBlockGroupCoverLayer`) and a stale doc link.

## What This Code Does

Removes the entire text-range-based table rendering pipeline (invisible inline text + PassthroughHostingView + TableHighlightOverlay + TableCellMap + sticky headers). Tables now exclusively use the attachment-based overlay approach established in T4 (NSTextAttachment placeholder + OverlayCoordinator positions NSHostingView(TableAttachmentView)).

The print path was rewritten before deletion: `appendTableInlineText` (which depended on TableCellMap, TableAttributes, TableColorInfo, buildTableTabStops) was replaced by `appendTablePrintText`, which uses only `TableColumnSizer.computeWidths()` and inline tab-stop construction. The new method is self-contained with no dependencies on deleted types.

State changes:
- `OverlayEntry` stripped to 4 fields (view, attachment, block, preferredWidth) from 8.
- `OverlayCoordinator` lost `stickyHeaders`, `tableRangeIndex`, `pendingVisualHeights`, `reconciledThroughOffset`, `reconcileLayoutThroughViewport()`, `invalidateReconciliation()`, `shouldPositionEntry()`.
- `EntranceAnimator` lost `tableDelays`, the `table-` prefix branch in `processBlockGroups`, and the `TableAttributes.range` check in `blockGroupID`.
- `CodeBlockBackgroundTextView` lost `cachedTableRanges`, `isTableRangeCacheValid`, `selectionDragHandler`, and the `copy`/`setSelectedRanges`/`draw` overrides that were now trivial.
- `repositionOverlays()` simplified: iterates all entries directly instead of filtering through `shouldPositionEntry`.
- `positionEntry()` simplified: only the attachment branch remains.
- `buildPositionIndex()` only enumerates `.attachment` attributes (no more `TableAttributes.range`).
- Scroll observation simplified: handler calls `repositionOverlays()` directly instead of `handleScrollBoundsChange()` with sticky header logic.

## Transitions Identified

1. **Print path routing** (MarkdownTextStorageBuilder.swift:235-253): `isPrint ? appendTablePrintText : appendTableAttachment`. Safe -- the two paths are independent. Print path uses scaleFactor and colors; non-print uses attachment + overlay. No shared mutable state.

2. **Overlay repositioning on width change** (OverlayCoordinator.swift:110-119): Width change detection rebuilds layout context. Simplified from the old version that also cleared `lastAppliedVisualHeight`, sticky headers, and invalidated reconciliation. Now just rebuilds context and repositions all entries. Safe -- no stale state to accumulate.

3. **Entrance animation** (OverlayCoordinator+EntranceAnimation.swift): Now only handles attachment-based entries. Tables go through the attachment path automatically. No more tableRangeID or highlightOverlay alpha animation. Clean.

## Convention Check
**Files examined for context:** `OverlayCoordinator+Factories.swift` (neighboring factory), `MermaidBlockView.swift` (overlay pattern), `EntranceAnimator+Layers.swift` (animation helpers), `CodeBlockBackgroundTextView+CodeBlocks.swift` (drawing pattern), `MarkdownTextStorageBuilder+Blocks.swift` (builder extension pattern)
**Violations:** 0

## Findings

### [EntranceAnimator+Layers.swift:62-83] Dead function: makeBlockGroupCoverLayer
**Severity:** minor
**Category:** convention
```swift
func makeBlockGroupCoverLayer(
    frames: [CGRect],
    in textView: NSTextView
) -> CALayer {
```
**Problem:** This method's only caller was the `table-` prefix branch in `processBlockGroups`, which was deleted in this commit. The method now has zero callers.
**Impact:** Dead code. No functional issue, but adds confusion during future maintenance.
**Fix:** Delete `makeBlockGroupCoverLayer` (lines 62-83 of EntranceAnimator+Layers.swift).

### [TableAttachmentView.swift:8] Stale doc comment reference
**Severity:** minor
**Category:** convention
```swift
/// Visually identical to ``TableBlockView`` — same column sizing, header styling,
```
**Problem:** `TableBlockView` was deleted in this commit. The doc comment double-backtick link is now broken.
**Impact:** Misleading documentation. No functional issue.
**Fix:** Change to "Visually identical to the former TableBlockView" or remove the reference entirely.

## Acceptance Criteria

| Criterion | Met? | Evidence |
|-----------|------|----------|
| `swift build` succeeds with zero warnings related to table deletions | Yes | Build complete! (1.32s), zero warnings |
| `swift test` passes, test count drops by deleted files + 2 OC tests | Yes | 669 tests in 63 suites passed (down from 708 in 65 suites) |
| Stale reference grep returns zero matches in non-iOS files | Yes | All matches are in comments, `TableAttachmentData.tableRangeID` (T1 pipeline), or iOS `TableBlockViewiOS` |
| `swiftformat .` passes | Yes | 0/213 files require formatting |
| `swiftlint lint` passes | Yes | 4 violations, all pre-existing (2 in MermaidTemplateLoader, 2 in SelectableTextView+Coordinator) |
| 11 source files deleted | Yes | All 11 verified absent from worktree |
| 2 test files deleted | Yes | Both verified absent from worktree |
| Print path rewritten with appendTablePrintText | Yes | MarkdownTextStorageBuilder+TablePrint.swift:27-101 |
| OverlayEntry stripped of table fields | Yes | OverlayCoordinator.swift:12-29 |
| Sticky header logic removed | Yes | OverlayCoordinator+Observation.swift, stickyHeaders property removed |
| tableRangeIndex removed | Yes | OverlayCoordinator+PositionIndex.swift, property and enumeration removed |
| tableDelays removed from EntranceAnimator | Yes | EntranceAnimator.swift, all references removed |
| TableAttributes.range check removed from blockGroupID | Yes | EntranceAnimator.swift:366-388 |
| updateTableFindHighlights calls removed | Yes | SelectableTextView+Coordinator.swift, both calls removed |
| swiftUIAlignment extension moved to TableAttachmentView | Yes | TableAttachmentView.swift:186-194 |

## Verification Trail

### What I Verified
- **Build integrity**: `swift build` in worktree -- Build complete! (1.32s), zero errors, zero warnings
- **Test integrity**: `swift test` in worktree -- 669 tests in 63 suites passed (delta: -39 tests, -2 suites)
- **Format compliance**: `swiftformat --lint .` -- 0/213 files require formatting
- **Lint compliance**: `swiftlint lint` -- 4 violations, all pre-existing (verified by checking that MermaidTemplateLoader.swift was not modified in T5 and SelectableTextView+Coordinator.swift violations are file_length + orphaned_doc_comment from pre-T4)
- **File deletions**: All 13 files (11 source + 2 test) verified absent via filesystem check
- **Stale references**: Full grep of spec pattern across mkdn/ and mkdnTests/. All remaining matches are: (a) doc comments explaining what was replaced, (b) `TableAttachmentData.tableRangeID` from T1 pipeline (not stale), (c) iOS `TableBlockViewiOS` (expected per spec)
- **IDE diagnostic concerns**: `TableHighlightOverlay`, `TableCellMap`, `handleTableCopy`, `eraseTableSelectionHighlights`, `drawTableContainers`, `TableAttributes`, `tableDelays`, `updateTableFindHighlights` -- all confirmed zero matches in worktree. These are stale SourceKit/IDE cache, not real issues.
- **Dead code**: `makeBlockGroupCoverLayer` in EntranceAnimator+Layers.swift has zero callers after the `table-` branch removal
- **swiftUIAlignment extension**: Verified macOS uses `swiftUIAlignment` (TableAttachmentView.swift), iOS uses `swiftUIAlignmentiOS` (TableBlockViewiOS.swift) -- no name collision, separate `#if os()` guards
- **Print path**: `appendTablePrintText` uses `TableColumnSizer.computeWidths()`, `estimatePrintRowHeight`, `buildPrintTabStops` -- all self-contained, no dependencies on deleted types

### What I Dismissed
- **`tableRangeID` on `TableAttachmentData`**: This property is part of the T1 new pipeline, not the deleted old pipeline. It's set during attachment creation (`UUID().uuidString`) but appears unused by any consumer currently. This is T1's scope, not T5's.
- **`PassthroughHostingView` in comments**: Two references in doc comments explain what was replaced. Informational, not functional.
- **`TableCellMap`/`TableAttributes`/`TableColorInfo` in comments**: Three references in doc comments on the new `TablePrint` and `TableClipboardSerializer` files explain what they replace. Informational.
- **Pre-existing lint violations**: 4 errors in MermaidTemplateLoader.swift (period_spacing) and SelectableTextView+Coordinator.swift (file_length, orphaned_doc_comment). All verified pre-existing before T5.

### What I Could Not Verify
- **Print output quality**: The new `appendTablePrintText` path cannot be visually tested without launching the app and printing. The code structure is correct (tab stops, bold header, body font, paragraph spacing), but visual fidelity requires runtime verification in T7.
- **Entrance animation correctness**: Tables now go through the attachment-based entrance animation path. Cannot verify the stagger timing without runtime observation. The code path is structurally sound.

### Build Integrity
- `swift build` -> Build complete! (1.32s)
- `swift test` -> 669 tests in 63 suites passed after 1.178 seconds
- `swiftformat --lint .` -> 0/213 files require formatting
- `DEVELOPER_DIR=.../Xcode.app swiftlint lint` -> 4 violations, 4 serious (all pre-existing)

## What Was Done Well

- The `PrintRowStyle` struct in the new print file keeps `appendPrintRow` under the 6-parameter SwiftLint limit without sacrificing clarity.
- Removing the trivial `copy`, `setSelectedRanges`, and `draw` overrides from `CodeBlockBackgroundTextView` avoids `unneeded_override` lint violations -- proactive cleanup.
- The `swiftUIAlignment` extension was correctly identified as a dependency of `TableAttachmentView` (created in T3) and moved there, rather than being lost with `TableBlockView`.
- Net deletion of ~2,900 lines is substantial dead code removal that simplifies the codebase considerably.
