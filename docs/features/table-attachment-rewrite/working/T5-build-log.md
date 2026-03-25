### T5: Cleanup: delete obsolete table infrastructure
**Date:** 2026-03-24
**Status:** complete
**Files changed:**
- `mkdn/Core/Markdown/MarkdownTextStorageBuilder+TablePrint.swift` (new) — print-only table text generation replacing deleted `+TableInline.swift`
- `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` (modify) — removed `TableOverlayInfo` struct, switched print path from `appendTableInlineText` to `appendTablePrintText`
- `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` (modify) — removed `tableRangeID`, `highlightOverlay`, `cellMap`, `lastAppliedVisualHeight` from `OverlayEntry`; removed `stickyHeaders`, `tableRangeIndex`, `pendingVisualHeights`, `reconciledThroughOffset` properties; removed `reconcileLayoutThroughViewport`, `invalidateReconciliation`, `shouldPositionEntry` methods; simplified `repositionOverlays`, `hideAllOverlays`, `removeAllOverlays`, `removeStaleAttachmentOverlays`
- `mkdn/Features/Viewer/Views/OverlayCoordinator+Positioning.swift` (modify) — removed `tableRangeID` branch from `positionEntry`
- `mkdn/Features/Viewer/Views/OverlayCoordinator+PositionIndex.swift` (modify) — removed `tableRangeIndex` and `TableAttributes.range` enumeration
- `mkdn/Features/Viewer/Views/OverlayCoordinator+Observation.swift` (modify) — removed sticky header logic from scroll handler, removed `stickyHeaderHeight()`, simplified to just calling `repositionOverlays()`
- `mkdn/Features/Viewer/Views/OverlayCoordinator+EntranceAnimation.swift` (modify) — removed `tableDelays` parameter, `tableRangeID` branch, `highlightOverlay` alpha animation
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` (modify) — removed `cachedTableRanges`, `isTableRangeCacheValid`, `selectionDragHandler`; removed `handleTableCopy`, `eraseTableSelectionHighlights`, `drawTableContainers` calls; removed now-empty overrides (copy, setSelectedRanges, draw)
- `mkdn/Features/Viewer/Views/EntranceAnimator.swift` (modify) — removed `tableDelays` property and all its uses; removed `table-` prefix branch from `processBlockGroups`; removed `TableAttributes.range` check from `blockGroupID`
- `mkdn/Features/Viewer/Views/SelectableTextView.swift` (modify) — removed all `tableDelays:` arguments from `applyEntranceAnimation` calls
- `mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift` (modify) — removed `updateTableFindHighlights` calls
- `mkdn/Features/Viewer/Views/TableAttachmentView.swift` (modify) — added `swiftUIAlignment` extension on `TableColumnAlignment` (was in deleted `TableBlockView.swift`)
- `mkdnTests/Unit/Features/OverlayCoordinatorTests.swift` (modify) — removed 2 tests for deleted `tableRangeIndex`

**Files deleted (11 source + 2 test):**
- `mkdn/Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift`
- `mkdn/Core/Markdown/TableCellMap.swift`
- `mkdn/Core/Markdown/TableAttributes.swift`
- `mkdn/Features/Viewer/Views/TableBlockView.swift`
- `mkdn/Features/Viewer/Views/TableHeaderView.swift`
- `mkdn/Features/Viewer/Views/TableHighlightOverlay.swift`
- `mkdn/Features/Viewer/Views/OverlayCoordinator+TableOverlays.swift`
- `mkdn/Features/Viewer/Views/OverlayCoordinator+TableHeights.swift`
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+TableSelection.swift`
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+TableCopy.swift`
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+TablePrint.swift`
- `mkdnTests/Unit/Core/TableCellMapTests.swift`
- `mkdnTests/Unit/Core/TableAttributesTests.swift`

**Notes:**
- The `swiftUIAlignment` extension on `TableColumnAlignment` was defined in the deleted `TableBlockView.swift` but used by `TableAttachmentView.swift` (T3/T4). Moved it to `TableAttachmentView.swift`. The iOS equivalent (`swiftUIAlignmentiOS`) remains in `TableBlockViewiOS.swift`.
- Removed three now-trivial overrides from `CodeBlockBackgroundTextView` (copy, setSelectedRanges, draw) that would trigger swiftlint `unneeded_override` violations.
- Refactored `appendPrintRow` to use a `PrintRowStyle` struct to stay within the 6-parameter limit.

**Baseline (before changes):**
```
swift build: Build complete! (1.26s)
swift test: 708 tests in 65 suites passed
swiftlint: 7 violations, 7 serious (all pre-existing)
```

**Post-change (after changes):**
```
swift build: Build complete! (5.48s)
swift test: 669 tests in 63 suites passed
swiftlint: 4 violations, 4 serious (all pre-existing — 3 fewer than baseline because deleted files had violations)
```

Test count delta: -39 tests, -2 suites (TableCellMapTests suite, TableAttributesTests suite, plus 2 tests from OverlayCoordinatorTests).
