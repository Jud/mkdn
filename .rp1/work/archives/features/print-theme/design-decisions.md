# Design Decisions: Print-Friendly Theme

**Feature ID**: print-theme
**Created**: 2026-02-15

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Print palette architecture | Separate `PrintPalette` enum alongside `SolarizedDark`/`SolarizedLight`, NOT a new `AppTheme` case | Print is not a user-selectable screen theme. Adding it to `AppTheme` would require guard clauses in the theme picker, cycle logic, and test harness theme commands. A separate enum follows the existing theme definition pattern cleanly. | (a) Add `AppTheme.print` case -- rejected: pollutes screen theme system, requires UI guards. (b) Use a protocol -- rejected: over-engineered for one additional palette. |
| D2 | Print interception point | Override `print(_:)` on `CodeBlockBackgroundTextView`, create temporary view | The on-screen view is never modified, eliminating flicker (NFR-2). The temporary view is created, used for the print operation, then discarded. Clean separation of print vs screen rendering. | (a) Swap attributed string in-place, restore after print -- rejected: risks flicker and edge cases if print is cancelled. (b) Override `printOperation(for:)` -- rejected: less control over the full print flow. (c) Intercept at menu command level -- rejected: bypasses standard responder chain. |
| D3 | Builder API change | Add `build(blocks:colors:syntaxColors:)` overload; refactor internal `theme: AppTheme` to `syntaxColors: SyntaxColors` | Minimal public API change. The existing `build(blocks:theme:)` becomes a convenience that delegates. Internal methods only need `SyntaxColors` for syntax highlighting, not the full `AppTheme` enum. | (a) Create a `ThemePalette` protocol -- rejected: adds abstraction without proportional benefit. (b) Pass `AppTheme` for print by extending the enum -- rejected: see D1. (c) Color-transform existing attributed string -- rejected: fragile, must handle all attribute types. |
| D4 | Temporary print view: TextKit 1 vs TextKit 2 | TextKit 1 (default `NSTextView` initializer) | Print requires all content to be laid out before page generation. TextKit 1 performs synchronous full-document layout. TextKit 2's viewport-based layout is designed for on-screen scrolling and would require manual layout forcing which is unreliable for print. | (a) TextKit 2 with forced layout -- rejected: `NSTextLayoutManager.ensureLayout(for:)` does not guarantee all content is ready for page-based print. |
| D5 | Access to blocks at print time | Store `[IndexedBlock]` on `CodeBlockBackgroundTextView.printBlocks` | The text view receives `print:` and needs blocks to rebuild. Storing directly on the view is the simplest path. The coordinator already manages the view lifecycle and can keep it updated. | (a) Store markdown content string, re-parse at print time -- rejected: unnecessary parsing overhead, blocks are already available. (b) Look up blocks via responder chain or delegate -- rejected: more complex wiring for no benefit. |
| D6 | Overlay elements (tables, Mermaid, images) in print | Excluded from v1 scope | These are `NSHostingView` overlays positioned by `OverlayCoordinator`, not part of the `NSAttributedString`. Including them in print requires a fundamentally different approach (composite rendering). Requirements explicitly scope this out. | N/A -- follow-up feature. |
| D7 | Print syntax color palette | Dark, high-contrast colors inspired by print/IDE conventions (dark green, dark red, gray, dark amber, dark purple, dark blue, dark orange, dark red-pink) | Every color meets WCAG AA 4.5:1 contrast against white. Colors chosen to be mutually distinguishable while maintaining the visual hierarchy (comments de-emphasized, keywords/types prominent). | (a) Grayscale only -- rejected: loses semantic distinction between token types. (b) Solarized Light colors as-is -- rejected: designed for cream (#fdf6e3) background, insufficient contrast on pure white for some tokens. |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Theme definition pattern | Caseless enum with static properties | Codebase (`SolarizedDark.swift`, `SolarizedLight.swift`) | Follows existing codebase pattern exactly |
| Builder API style | Static method overload (not protocol) | Codebase (`MarkdownTextStorageBuilder` uses static methods throughout) | Consistent with existing builder API style |
| Color values for print | WCAG AA compliant, ink-efficient | Industry standard + NFR-5 requirement | Print readability and accessibility standards |
| Test framework | Swift Testing (`@Test`, `#expect`, `@Suite`) | KB patterns.md | Mandatory per project conventions |
| Print view creation | Programmatic `NSTextView` with TextKit 1 | Conservative default | TextKit 1 is battle-tested for print; TextKit 2 print support is less documented |
| Print font handling | Reuse existing `PlatformTypeConverter` fonts | Codebase | Same fonts for screen and print ensures content fidelity |
