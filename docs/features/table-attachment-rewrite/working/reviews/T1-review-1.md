# Code Review: T1 — Foundation data types: TableTextAttachment, TableAttachmentData, TableClipboardSerializer

**Date:** 2026-03-24
**Round:** 1
**Verdict:** pass

## Summary

Clean implementation of foundation data types for the table attachment pipeline. All four files are well-structured, match project conventions, and pass build/test/lint/format checks.

## What This Code Does

Introduces four new files establishing the data layer for the table attachment rewrite:

1. **`TableAttachmentData`** -- a `Sendable` struct carrying `[TableColumn]`, `[[AttributedString]]`, `blockIndex`, and `tableRangeID`. Cross-platform (no `#if` guard).

2. **`TableTextAttachment`** -- an `NSTextAttachment` subclass (macOS-only, `#if os(macOS)`) that stores a `TableAttachmentData?`. Sets `allowsTextAttachmentView = true` in its designated init to enable the `NSTextAttachmentViewProvider` path. Marks `init(coder:)` as `@available(*, unavailable)`.

3. **`CellPosition`** -- standalone top-level struct (replacing `TableCellMap.CellPosition`) with identical semantics: `row == -1` for headers, `Comparable` by row-then-column, `Hashable`, `Sendable`.

4. **`SelectionShape`** -- enum with cases `.empty`, `.cells(Set<CellPosition>)`, `.rows(IndexSet)`, `.columns(IndexSet)`, `.rectangular(rows: Range<Int>, columns: Range<Int>)`, `.all`. `Sendable`.

5. **`TableClipboardSerializer`** -- uninhabitable enum with `tabDelimitedText()` and `markdownText()` static methods. `expandSelection()` normalizes all selection shapes into `Set<CellPosition>`. Tab-delimited output preserves column positions (empty string for unselected columns on selected rows). Markdown output synthesizes a placeholder header row when only data rows are selected.

State touched: none. These are pure data types and stateless functions. No mutable shared state.

## Transitions Identified

No state transitions in this code. All types are either immutable structs or stateless static functions. `TableTextAttachment.tableData` is a mutable `var` but only set during init via the convenience initializer.

## Convention Check
**Files examined for context:** `MarkdownBlock.swift` (TableColumn, TableColumnAlignment), `MarkdownRenderer.swift` (uninhabitable enum pattern), `TableColumnSizer.swift` (uninhabitable enum, static methods, platform imports), `TableCellMap.swift` (existing CellPosition)
**Violations:** 0

- File naming: PascalCase matching primary type. Correct.
- Uninhabitable enum pattern for stateless computation: matches `MarkdownRenderer`, `TableColumnSizer`. Correct.
- Platform guards: `#if os(macOS)` / `#else` for AppKit/UIKit imports matches `TableColumnSizer.swift`. Correct.
- Import grouping: Foundation/AppKit first, no intra-project imports. Correct.
- `public init` on public structs: explicit inits provided on `TableAttachmentData` and `CellPosition`. Correct.
- Doc comments: present on all public types and methods. Correct.
- `Sendable` conformance on value types. Correct.
- Test file naming: matches source type name. Correct.
- Test imports: `@testable import mkdnLib`, Swift Testing `@Suite`/`@Test`/`#expect`. Correct.
- `.none` renamed to `.empty` to satisfy SwiftLint's `discouraged_none_name`. Documented in build log. Correct.

## Findings

No critical, major, or minor findings.

## Acceptance Criteria

| Criterion | Met? | Evidence |
|-----------|------|----------|
| All tests pass | Yes | `swift test` -- 686 tests in 63 suites passed (667 baseline + 19 new) |
| `swift build` succeeds | Yes | Build complete (4.82s) |
| `swiftformat .` produces no changes on T1 files | Yes | `swiftformat --lint` on T1 files: 0/4 files require formatting |
| `swiftlint lint` passes (no new violations) | Yes | 4 violations, 4 serious (same pre-existing; 0 in new files) |
| Types are `public` where needed | Yes | `TableAttachmentData`, `TableTextAttachment`, `CellPosition`, `SelectionShape`, `TableClipboardSerializer` and their relevant members are all `public` |
| `CellPosition` and `SelectionShape` in `TableClipboardSerializer.swift` | Yes | Both defined in `mkdn/Core/Markdown/TableClipboardSerializer.swift` |
| `TableAttachmentData` is `Sendable` | Yes | `TableAttachmentData.swift:12` |
| `TableTextAttachment` sets `allowsTextAttachmentView = true` | Yes | `TableAttachmentData.swift:45`, tested in `TableAttachmentDataTests.swift:35` |
| `TableTextAttachment` macOS-only with `#if os(macOS)` | Yes | `TableAttachmentData.swift:33-58` |
| `TableAttachmentData` stores/retrieves test | Yes | `TableAttachmentDataTests.swift:9` |
| `allowsTextAttachmentView` test | Yes | `TableAttachmentDataTests.swift:34` |
| Tab-delimited `.all` test | Yes | `TableClipboardSerializerTests.swift:24` |
| Tab-delimited `.cells` test | Yes | `TableClipboardSerializerTests.swift:39` |
| Tab-delimited `.rectangular` test | Yes | `TableClipboardSerializerTests.swift:56` |
| Tab-delimited `.rows` test | Yes | `TableClipboardSerializerTests.swift:72` |
| Tab-delimited `.columns` test | Yes | `TableClipboardSerializerTests.swift:88` |
| Tab-delimited `.none`/`.empty` test | Yes | `TableClipboardSerializerTests.swift:107` |
| Markdown output with alignment markers test | Yes | `TableClipboardSerializerTests.swift:132` |
| Header row included when selected test | Yes | `TableClipboardSerializerTests.swift:117` |

## Verification Trail

### What I Verified
- **Build integrity**: `swift build` in worktree -- Build complete (4.82s), 1 pre-existing deprecation warning only
- **Test integrity**: `swift test` in worktree -- 686 tests in 63 suites passed. Matches builder's post-change claim (686 tests, 63 suites)
- **Lint compliance**: `swiftlint lint` -- 4 pre-existing violations, 0 in new files. Matches baseline exactly
- **Format compliance**: `swiftformat --lint` on all 4 T1 files -- 0 files require formatting
- **Convention alignment**: Read 4 neighboring files (MarkdownBlock.swift, MarkdownRenderer.swift, TableColumnSizer.swift, TableCellMap.swift) to verify naming, structure, visibility, and pattern adherence
- **CellPosition compatibility**: Verified new standalone `CellPosition` is structurally identical to `TableCellMap.CellPosition`. No compile-time ambiguity (existing code uses fully-qualified `TableCellMap.CellPosition`)
- **Sendable correctness**: Verified all associated value types in `SelectionShape` and all fields in `TableAttachmentData` are `Sendable`
- **Commit scope**: `git diff f85efdc..de2e314 --stat` confirmed T1 commit only touches the 4 specified files (571 insertions)

### What I Dismissed
- **Duplicate `CellPosition` type**: Two `CellPosition` types exist (`TableCellMap.CellPosition` nested, new top-level `CellPosition`). Not a problem -- build succeeds, existing code uses fully-qualified names, and T5 will delete `TableCellMap` entirely.
- **`.none` renamed to `.empty`**: Documented deviation from spec. Required by SwiftLint `discouraged_none_name` rule. Semantically equivalent.
- **`TableTextAttachment` is not `Sendable`**: Correct -- NSTextAttachment is a class, and the spec only requires `TableAttachmentData` to be `Sendable`.

### What I Could Not Verify
- Runtime behavior of `NSTextAttachment.allowsTextAttachmentView` with TextKit 2 -- requires live app testing (T7 covers this).

### Build Integrity
- `swift build` -> Build complete! (4.82s)
- `swift test` -> 686 tests in 63 suites passed after 1.113 seconds
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint` -> 4 violations, 4 serious (all pre-existing)
- `swiftformat --lint` on T1 files -> 0/4 files require formatting

## What Was Done Well

- Correct use of uninhabitable enum pattern matching `MarkdownRenderer` and `TableColumnSizer`.
- `expandSelection()` as a private normalizer that converts all `SelectionShape` cases into a uniform `Set<CellPosition>` simplifies both serialization methods.
- Defensive bounds checking in `cellText()` for out-of-range row/column values.
- `@available(*, unavailable)` on `init(coder:)` prevents accidental archiving of the attachment.
- Clean test separation: `TableAttachmentDataTests` for the attachment class, `TableClipboardSerializerTests` for serialization logic plus `CellPosition` and `SelectionShape` behavior.
- Good test coverage: 19 tests covering all selection shapes, both output formats, and CellPosition ordering/equality/hashable.
