### T2: TableSelectionState and TableFindAdapter
**Date:** 2026-03-24
**Status:** complete
**Files changed:**
- `mkdn/Features/Viewer/Views/TableSelectionState.swift` — new file: `@Observable @MainActor` selection state class with selection shape management, find match tracking, and cell query methods
- `mkdn/Features/Viewer/Views/TableFindAdapter.swift` — new file: uninhabitable enum with static `findMatches()` method for searching table cell content
- `mkdnTests/Unit/Features/TableSelectionStateTests.swift` — new file: 17 tests covering all selection mutations, query methods, find state queries, and edge cases
- `mkdnTests/Unit/Features/TableFindAdapterTests.swift` — new file: 10 tests covering empty query, single/multiple matches, case sensitivity, header search, partial matches, and ordering

**Notes:**
- Used `.empty` throughout (not `.none`) per T1's SwiftLint compliance rename.
- Extracted `selectionBounds(including:)` private helper from `extendSelection(to:)` to satisfy SwiftLint's `function_body_length` (50 line max) and `force_unwrapping` rules. The helper returns an optional tuple of row/column ranges, with `nil` signaling fallback to `selectCell`.
- `TableFindAdapter` is not wrapped in `#if os(macOS)` since it only depends on `Foundation` types (`TableColumn`, `AttributedString`, `CellPosition`) that are cross-platform. This matches the pattern of `TableClipboardSerializer` which is also cross-platform.
- `TableSelectionState` is wrapped in `#if os(macOS)` since it depends on `@Observable` patterns used only in the macOS table attachment pipeline, matching `FindState`'s guard.
- Test file for `TableFindAdapterTests` placed in `mkdnTests/Unit/Features/` alongside other feature tests. `TableFindAdapter` source is in Views/ directory per spec.

**Baseline (before changes):**
```
swift build: Build complete! (1.19s)
swift test: Test run with 686 tests in 63 suites passed
swiftlint lint: 4 violations, 4 serious (pre-existing)
```

**Post-change (after changes):**
```
swift build: Build complete! (4.83s)
swift test: Test run with 713 tests in 65 suites passed
swiftlint lint: 4 violations, 4 serious (same pre-existing, 0 in new files)
swiftformat: 0 files formatted (clean)
```
