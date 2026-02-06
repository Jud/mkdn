# Design Decisions: Syntax Highlighting for Code Blocks

**Feature ID**: syntax-highlighting
**Created**: 2026-02-06

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | File placement for ThemeOutputFormat | Extract to `mkdn/Core/Markdown/ThemeOutputFormat.swift` | Single-responsibility: the output format adapter is a rendering pipeline component, not a view. Extracting it makes it independently testable and aligns with the project's small-file convention. Core/Markdown/ is where rendering pipeline code lives. | Keep inline in CodeBlockView.swift (simpler, fewer files, but harder to test in isolation and mixes concerns) |
| D2 | plainTextColor value passed to ThemeOutputFormat | Keep existing: `syntaxColors.comment` | The existing code passes `syntaxColors.comment` as plainTextColor. CL-005 left this as an implementation decision. Changing it to `codeForeground` would alter existing visual behavior. The comment color provides subtle differentiation for plain text tokens within highlighted Swift blocks. For non-Swift blocks, `codeForeground` is used directly in CodeBlockView (not via ThemeOutputFormat), so this only affects the Swift highlighting path. | Use `colors.codeForeground` (would change visual appearance of unrecognized tokens in Swift blocks) |
| D3 | Sendable conformance approach | Explicit `Sendable` conformance on both ThemeOutputFormat and Builder | Swift 6 strict concurrency requires Sendable safety. Both types contain only value-type stored properties (Color, Dictionary of value types, AttributedString), so Sendable conformance is correct. Explicit conformance makes the intent clear and prevents future regressions if a non-Sendable property were added. | Implicit Sendable inference (works for structs with all-Sendable fields, but less explicit and could regress silently) |
| D4 | Test scope for ThemeOutputFormat | Test Builder behavior only (token coloring, plain text, whitespace, build) -- do NOT test Splash tokenization or SwiftUI rendering | Tests should validate app-specific logic: the mapping from TokenType to Color, the fallback behavior, and whitespace handling. Testing that Splash correctly tokenizes Swift code is library behavior verification. Testing that SwiftUI Text renders colors is framework behavior verification. | Integration test with Splash SyntaxHighlighter end-to-end (tests library behavior, brittle to Splash changes); Visual snapshot tests (heavy infrastructure, not worth it for this scope) |
| D5 | Scope of rename | Rename type only (SolarizedOutputFormat -> ThemeOutputFormat). No changes to SolarizedDark/SolarizedLight theme enum names. | FR-001 and NFR-006 specifically target the highlighting adapter naming. The theme definition files (SolarizedDark.swift, SolarizedLight.swift) are correctly named after the actual theme they implement -- "Solarized" is the theme identity there, not a false coupling. BR-002 states "theme identity is the responsibility of the theme layer." | Also rename SolarizedDark/SolarizedLight (over-scoped; those names accurately describe the themes they define) |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| File placement for ThemeOutputFormat | `Core/Markdown/ThemeOutputFormat.swift` | Codebase pattern (Core/Markdown/ contains rendering pipeline) | CL-004 left this as implementation decision; Core/Markdown/ is the established location for rendering pipeline code |
| plainTextColor value | `syntaxColors.comment` (preserve existing) | Existing codebase | CL-005 left this as implementation decision; preserving existing behavior avoids unintended visual changes |
| Sendable approach | Explicit conformance | KB patterns.md (Swift 6 strict concurrency mandate) | NFR-007 requires Sendable compatibility; explicit is safer than implicit inference |
| Test framework | Swift Testing (@Suite, @Test, #expect) | KB patterns.md | Project standard; all existing tests use Swift Testing |
| Test isolation | No @MainActor needed on tests | MEMORY.md (actor isolation guidance) | ThemeOutputFormat is a plain value type, no actor isolation required |
