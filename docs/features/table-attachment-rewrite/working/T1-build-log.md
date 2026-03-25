### T1: Foundation data types: TableTextAttachment, TableAttachmentData, TableClipboardSerializer
**Date:** 2026-03-24
**Status:** complete
**Files changed:**
- `mkdn/Core/Markdown/TableAttachmentData.swift` — new file: `TableAttachmentData` struct (Sendable data carrier) and `TableTextAttachment` class (NSTextAttachment subclass, macOS-only via `#if os(macOS)`)
- `mkdn/Core/Markdown/TableClipboardSerializer.swift` — new file: `CellPosition` struct, `SelectionShape` enum, `TableClipboardSerializer` uninhabitable enum with `tabDelimitedText()` and `markdownText()` static methods
- `mkdnTests/Unit/Core/TableAttachmentDataTests.swift` — new file: 4 tests for TableTextAttachment and TableAttachmentData
- `mkdnTests/Unit/Core/TableClipboardSerializerTests.swift` — new file: 15 tests for serializer output across all SelectionShape cases, plus CellPosition ordering/equality/hashable tests

**Notes:**
- Renamed `SelectionShape.none` to `SelectionShape.empty` because SwiftLint's `discouraged_none_name` rule forbids `.none` (compiler confusion with `Optional.none`). This deviation from the spec is required for lint compliance. T2's spec references `.none` and will need to use `.empty` instead.
- `CellPosition` is defined as a standalone top-level struct (not nested inside `TableCellMap` as in the old code) per spec. Identical semantics: `row == -1` for header, `Comparable` sorts by row then column.
- `TableTextAttachment` uses `init(data:ofType:)` as the designated init (required by NSTextAttachment) with `allowsTextAttachmentView = true` set there, plus a convenience `init(tableData:)`. `init(coder:)` is marked `@available(*, unavailable)` since the attachment is not archivable.

**Baseline (before changes):**
```
swift build: Build complete! (1.22s)
swift test: Test run with 667 tests in 61 suites passed
swiftlint lint: 4 violations, 4 serious (pre-existing)
```

**Post-change (after changes):**
```
swift build: Build complete! (4.91s)
swift test: Test run with 686 tests in 63 suites passed
swiftlint lint: 4 violations, 4 serious (same pre-existing, 0 in new files)
```
