# Quick Build: Fix Code Block Rendering

**Created**: 2026-02-07T00:00:00Z
**Request**: Fix code block rendering issue -- duplicate MarkdownBlock IDs causing SwiftUI ForEach corruption, plus defensive whitespace color fix in ThemeOutputFormat.
**Scope**: Small

## Plan

**Reasoning**: 3 source files affected (MarkdownBlock.swift, MarkdownRenderer.swift, ThemeOutputFormat.swift) plus 2 test files. Single system (rendering pipeline). Risk is medium because ID changes affect SwiftUI diffing and animation state, but the fix is well-scoped and the approach is clear.

**Files Affected**:
- `mkdn/Core/Markdown/MarkdownBlock.swift` -- content-based ID computation (thematicBreak always returns "hr")
- `mkdn/Core/Markdown/MarkdownRenderer.swift` -- post-process rendered blocks to deduplicate IDs
- `mkdn/Core/Markdown/ThemeOutputFormat.swift` -- `addWhitespace()` missing foreground color
- `mkdnTests/Unit/Core/MarkdownBlockTests.swift` -- add duplicate ID tests
- `mkdnTests/Unit/Core/ThemeOutputFormatTests.swift` -- update whitespace test expectation

**Approach**: The primary fix deduplicates block IDs by post-processing the rendered block array in `MarkdownRenderer.render()`. After the visitor produces blocks, we scan for duplicate IDs and append occurrence suffixes (`-1`, `-2`, etc.) to make them unique. This requires changing `MarkdownBlock.id` from a computed property to a stored property so we can mutate it during post-processing. The secondary fix adds `foregroundColor = plainTextColor` to `addWhitespace()` in ThemeOutputFormat for consistency with the other builder methods. Both fixes are verified with new unit tests.

**Estimated Effort**: 1.5 hours

## Tasks

- [ ] **T1**: Refactor `MarkdownBlock.id` from computed to stored property. Add an `init`-time computed `contentID` (using the existing switch logic), store it as `id`. Add a `mutating` method or make `id` settable so the renderer can append dedup suffixes. Keep `stableHash` and the existing ID format for all cases. `[complexity:medium]`
- [ ] **T2**: Add ID deduplication post-processing in `MarkdownRenderer.render(document:theme:)`. After `visitor.visitDocument()` returns blocks, scan for duplicate IDs. For any ID appearing N>1 times, append `-0`, `-1`, ..., `-N-1` suffixes to make each unique. Return the deduplicated array. `[complexity:simple]`
- [ ] **T3**: Fix `ThemeOutputFormat.Builder.addWhitespace()` to set `foregroundColor = plainTextColor` on the whitespace AttributedString, matching the behavior of `addPlainText()` and `addToken()`. Update the existing test in `ThemeOutputFormatTests` that asserts `foregroundColor == nil` for whitespace to instead assert `foregroundColor == plainTextColor`. `[complexity:simple]`
- [ ] **T4**: Add tests for duplicate block IDs in `MarkdownBlockTests.swift`. Test that two `.thematicBreak` blocks rendered from a document with multiple `---` produce different IDs. Test that duplicate paragraphs with identical text also get unique IDs. Test that blocks with already-unique IDs are not modified. `[complexity:simple]`
- [ ] **T5**: Integration verification -- run `swift build` and `swift test` to confirm all changes compile and pass, then run SwiftLint and SwiftFormat. `[complexity:simple]`

## Implementation Summary

{To be added by task-builder}

## Verification

{To be added by task-reviewer if --review flag used}
