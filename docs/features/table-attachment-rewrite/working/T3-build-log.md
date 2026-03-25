### T3: TableAttachmentView (SwiftUI visual rendering only)
**Date:** 2026-03-24
**Status:** complete
**Files changed:**
- `mkdn/Features/Viewer/Views/TableAttachmentView.swift` — new file: SwiftUI table rendering view for attachment pipeline

**Notes:**
- Layout matches `TableBlockView` exactly: same VStack/HStack structure, same padding (horizontal 13, vertical 6), same zebra striping, same rounded corner border, same font scaling.
- Uses `containerWidth` property directly (no `OverlayContainerState` dependency) since the attachment provider will supply the width.
- Reuses the existing `TableColumnAlignment.swiftUIAlignment` extension from `TableBlockView.swift` (same module, no duplicate needed). T6 will delete the one in `TableBlockView.swift`.
- `SizingCache` is a private class matching `TableBlockView`'s pattern, caching `TableColumnSizer.Result` keyed on width and scale factor.
- No selection, find, or copy behavior — those will be added in T4.

**Baseline (before changes):**
```
swift build — Build complete! (46.25s)
swift test — 667 tests in 61 suites passed
swiftlint — 5 pre-existing violations (none in new files)
```

**Post-change (after changes):**
```
swift build — Build complete! (5.06s)
swift test — 667 tests in 61 suites passed
swiftlint — 0 violations in TableAttachmentView.swift
```
