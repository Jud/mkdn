### T6: Find-in-page integration for table overlays
**Date:** 2026-03-24
**Status:** complete
**Files changed:**
- `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` (modify) — added `weak var findState: FindState?` property; passed `findState` to `makeTableAttachmentOverlay` call
- `mkdn/Features/Viewer/Views/OverlayCoordinator+Factories.swift` (modify) — added `findState: FindState?` parameter to `makeTableAttachmentOverlay`; injects `FindState` into the `NSHostingView` environment when non-nil
- `mkdn/Features/Viewer/Views/SelectableTextView.swift` (modify) — set `coordinator.overlayCoordinator.findState = findState` before `updateOverlays` call in `refreshOverlays`
- `mkdn/Features/Viewer/Views/TableAttachmentView.swift` (modify) — added `@Environment(FindState.self)` optional property; added three `onChange` observers (query, currentMatchIndex, isVisible) that drive `TableFindAdapter` to populate `selectionState.findMatches`; added `updateFindHighlights` and `updateFindCurrentMatch` helper methods

**Notes:**
- Used Option A from the spec: `FindState` threaded through `OverlayCoordinator` as a weak property, set from `SelectableTextView.refreshOverlays()`.
- The `FindState` environment injection uses conditional branching (`if let findState`) to avoid type erasure when `findState` is nil.
- Table cells show passive find highlighting (yellow at 0.15 opacity) for all matches. The `currentFindMatch` is always nil because table cells don't participate in the global match index navigation — they are overlays outside the attributed string.

**Baseline (before changes):**
```
swift build: Build complete! (1.22s)
swift test: 669 tests in 63 suites passed
swiftlint: 4 violations, 4 serious (all pre-existing)
```

**Post-change (after changes):**
```
swift build: Build complete! (2.88s)
swift test: 669 tests in 63 suites passed
swiftlint: 4 violations, 4 serious (all pre-existing)
swiftformat: 0/213 files formatted
```
