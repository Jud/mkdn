# Design Decisions: Terminal-Consistent Theming

**Feature ID**: terminal-consistent-theming
**Created**: 2026-02-07

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Cache key strategy for theme-aware Mermaid rendering | Include `theme.rawValue` in the DJB2 hash input alongside the Mermaid source code | Simple and non-breaking. Both `MermaidCache` and `MermaidImageStore` already key on `UInt64`. The hash input changes from `code` to `code + theme.rawValue`. No structural changes to the cache types. Capacity remains at 50 entries shared across all themes, which is sufficient for typical documents (at most ~25 diagrams with 2 variants each). | (a) Separate cache instances per theme -- doubles memory overhead and code complexity for no functional benefit. (b) Clear entire cache on theme change -- discards valid cached entries and forces re-render of all diagrams, causing unnecessary loading spinners. |
| D2 | Flash prevention at launch | Read `NSApp.effectiveAppearance` in `AppSettings.init()` to set the initial `systemColorScheme` | Resolves the correct OS appearance before any SwiftUI view body is evaluated, ensuring the first frame renders with the correct theme. Uses `NSAppearance.currentDrawing()` as fallback if `NSApp` is nil. The existing `ContentView.onAppear` / `.onChange` bridge continues to keep the value in sync for runtime changes. | (a) Accept potential one-frame flash and rely solely on the SwiftUI bridge -- violates REQ-009 which requires no visible flash. (b) Use only `NSAppearance.currentDrawing()` -- less reliable than `NSApp.effectiveAppearance` for the app-level appearance. |
| D3 | MermaidBlockView init-time cache lookup removal | Remove the synchronous cache lookup from `MermaidBlockView.init(code:)` and rely entirely on `.task(id:)` for rendering and cache retrieval | The init-time lookup was an optimization for LazyVStack view recycling, allowing instant display of previously rendered diagrams. However, with theme-aware cache keys, the lookup needs the current `AppTheme`, which comes from `@Environment(AppSettings.self)` -- not yet populated at `init` time. Moving the lookup into `.task(id:)` (which fires within the same layout pass) produces negligible perceived latency and eliminates the environment availability problem. | (a) Pass `theme` as an explicit init parameter from the parent view -- adds coupling, requires changes to `MarkdownBlockView`, and the parent also reads theme from the environment so the same timing issue applies to init. (b) Keep init-time lookup with a hardcoded `.solarizedDark` fallback -- would show the wrong cached image for light mode users. |
| D4 | Mermaid JS rendering theme selection | Map `AppTheme.solarizedDark` to Mermaid's built-in `"dark"` theme and `AppTheme.solarizedLight` to `"default"` | Mermaid's built-in themes provide reasonable dark/light appearances that harmonize with the Solarized palette without requiring custom color configuration. This keeps the JS call simple and avoids deep coupling to Mermaid's themeVariables API. | (a) Pass full Solarized color palette as Mermaid `themeVariables` -- significantly more complex, tightly coupled to Mermaid internals, and the visual improvement is marginal since diagrams are rendered as images within a Solarized-themed container. (b) Render all diagrams with a single theme -- creates visual mismatch when the app switches between dark and light. |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| State management for theme | `@Observable` AppSettings (existing) | KB patterns.md | Project mandates `@Observable`, and AppSettings already manages theme state. No new state types needed. |
| Persistence mechanism | UserDefaults (existing) | Codebase (AppSettings.swift) | Already in use for themeMode. No change needed. |
| OS appearance detection at init | `NSApp.effectiveAppearance` | macOS 14+ API | Built-in, no dependency. Standard approach for reading system appearance outside SwiftUI. |
| Mermaid theme mapping | Mermaid built-in "dark"/"default" | Conservative default | Avoids unverified assumptions about beautiful-mermaid's themeVariables support. Uses well-documented Mermaid theme names. |
| Test framework | Swift Testing (`@Test`, `#expect`, `@Suite`) | KB patterns.md, codebase | All existing tests use Swift Testing. New tests follow the same pattern. |
| Cache eviction strategy | Shared LRU across theme variants | Codebase (MermaidCache) | Existing 50-entry LRU handles the doubled key space naturally. Most documents have far fewer than 25 diagrams. |
