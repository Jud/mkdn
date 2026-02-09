# Design Decisions: Block Rendering Fix

**Feature ID**: block-rendering-fix
**Created**: 2026-02-07

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | How to make block IDs unique | Wrapper struct (`IndexedBlock`) at renderer boundary | Minimal code churn; enum stays unchanged; all nested ForEach loops in MarkdownBlockView unaffected; 6-line struct addition | (a) Restructure MarkdownBlock from enum to struct with inner MarkdownBlockKind -- 30+ pattern match changes across views and tests, violates scope constraint against UI component changes; (b) Add index as associated value to every enum case -- verbose, error-prone, requires threading indices through all visitor conversion methods; (c) Post-process IDs on existing enum -- impossible because `id` is a computed property with no stored state |
| D2 | ID composition format | `"{index}-{contentID}"` string | Simple string concatenation; index prefix guarantees uniqueness within a ForEach; contentID suffix preserves content-based stability for SwiftUI diffing when blocks don't move; human-readable for debugging | (a) Index only (`"\(index)"`) -- loses content-based stability, causing unnecessary view recreation when blocks are reordered; (b) UUID per render -- non-deterministic, violates REQ-003; (c) Hash of combined index+content -- less readable, no functional advantage |
| D3 | Scope of uniqueness fix | Top-level blocks only (via IndexedBlock at renderer output); nested blocks retain content-based IDs from MarkdownBlock enum | Fixes all reported bugs (thematic breaks, duplicate paragraphs at document level); nested duplicate blocks inside a single blockquote or list item are an unreported edge case; avoids changes to MarkdownBlockView which is explicitly out of scope | Full-depth uniqueness via restructuring MarkdownBlock to struct with recursive indexing -- too invasive, changes MarkdownBlockView's switch statement and all pattern matches |
| D4 | Whitespace foreground color value | Use `plainTextColor` parameter from ThemeOutputFormat | Consistent with `addPlainText` behavior; whitespace characters have no visible glyphs so the exact color is irrelevant to visual output; the fix ensures every AttributedString run has a non-nil foregroundColor, preventing SwiftUI Text from inferring inconsistent colors across run boundaries | (a) Hardcoded Color.clear -- not theme-aware, would break if SwiftUI ever uses foreground color for whitespace metrics; (b) Leave as nil -- this IS the bug |
| D5 | ForEach identity source | Direct `ForEach(renderedBlocks)` using IndexedBlock's Identifiable conformance | IndexedBlock carries both unique `id` and `index`; eliminates need for `Array(renderedBlocks.enumerated())` wrapper; cleaner, more idiomatic SwiftUI | (a) Keep `enumerated()` with `id: \.element.id` -- unnecessary complexity now that IndexedBlock provides both identity and position; (b) Use `id: \.offset` -- breaks SwiftUI diffing when blocks are inserted/removed because all subsequent indices shift |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Wrapper type location | Same file as MarkdownBlock (`MarkdownBlock.swift`) | Codebase pattern (related types colocated) | IndexedBlock is a thin wrapper over MarkdownBlock; same conceptual unit |
| Test framework | Swift Testing (@Suite, @Test, #expect) | KB patterns.md, existing test files | All existing tests use Swift Testing; project rule prohibits XCTest |
| Test file organization | Add to existing test suites (MarkdownBlockTests, ThemeOutputFormatTests, MarkdownRendererTests) | Existing test structure | New tests cover existing types; no new test files needed |
| Renderer API design | Both `render(document:theme:)` and `render(text:theme:)` return `[IndexedBlock]` | Consistent public API | Both methods are public; inconsistent return types would be confusing |
| MarkdownBlock enum changes | None -- keep Identifiable conformance with content-based ID | Scope constraint (no UI component changes) | Inner ForEach loops in MarkdownBlockView depend on MarkdownBlock.Identifiable; removing it would require MarkdownBlockView changes |
