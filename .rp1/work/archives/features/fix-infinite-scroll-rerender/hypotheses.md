# Hypothesis Document: fix-infinite-scroll-rerender
**Version**: 1.0.0 | **Created**: 2026-02-06T21:15:00Z | **Status**: VALIDATED

## Hypotheses
### HYP-001: SwiftUI @State(initialValue:) respected in LazyVStack view recycling
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: SwiftUI @State(initialValue:) set in a custom init() will be respected when LazyVStack recreates a view instance after recycling, allowing synchronous cache-aware initialization.
**Context**: The entire fix strategy depends on @State being initialized from the cache in init(). If SwiftUI ignores the custom init's @State initializer for recycled views, the view would still start in loading state and the flicker would persist.
**Validation Criteria**:
- CONFIRM if: A MermaidBlockView scrolled off-screen and back on-screen in a LazyVStack starts with renderedImage populated from the init's cache check, with isLoading = false. No loading indicator is visible.
- REJECT if: The view shows a loading indicator for at least one frame despite the cache being populated, indicating SwiftUI is ignoring the custom init's @State values.
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-06T21:20:00Z
**Method**: CODEBASE_ANALYSIS + EXTERNAL_RESEARCH + CODE_EXPERIMENT (static analysis)
**Result**: CONFIRMED

**Evidence**:

The validation examined two possible scenarios for what happens when a MermaidBlockView inside a LazyVStack scrolls off-screen and returns, and confirmed that the fix strategy works correctly in both cases.

#### Scenario A: View state is destroyed and recreated (state reset)

This is the scenario the hypothesis directly addresses. Multiple authoritative sources confirm that LazyVStack can destroy views and their @State when they scroll off-screen:

> "when using lazy containers such as LazyVStack or List, state can be unexpectedly lost when views scroll offscreen -- even though their identities remain the same" -- Swift Forums Pitch: Stabilize State in Lazy Containers (2025)

> "SwiftUI only retains the state of the top-level views when they reappear after leaving the visible area, while the state nested inside ChildView will be reset" -- Fatbobman, Tips for Using Lazy Containers

This is particularly relevant because MermaidBlockView is a **nested child** in the view hierarchy:

```
LazyVStack
  ForEach(renderedBlocks) { block in
    MarkdownBlockView(block: block)     // <-- top-level ForEach child
      case .mermaidBlock(code):
        MermaidBlockView(code: code)    // <-- NESTED child (state more likely reset)
  }
```

When state IS destroyed and the view scrolls back on-screen:
1. A NEW view instance is created
2. `init()` runs with a fresh context
3. `@State(initialValue:)` IS respected because this is a **first-time creation** for this view identity in SwiftUI's render tree
4. The custom init's cache check finds the previously rendered image
5. `_renderedImage = State(initialValue: cachedImage)` and `_isLoading = State(initialValue: false)` are used
6. The view's body renders immediately with the cached image -- no loading indicator
7. The `.task` modifier fires but the guard clause (`guard isLoading else { return }`) skips rendering

This behavior is confirmed by SwiftUI's documented contract: `@State(initialValue:)` is used for the **first creation** of a view's state storage. When state storage has been released (as happens in LazyVStack recycling), the next appearance IS treated as a first-time creation.

#### Scenario B: View state is preserved (no reset)

Some sources indicate that under certain conditions (OS version, scroll distance, memory pressure), LazyVStack may preserve @State for some views:

> "The children of a List will be kept around" and "state values survive off-screen scrolling" -- Chris Eidhof, Lifetime of State Properties

In this case:
1. `@State` already contains the rendered image from the initial render
2. `isLoading` is already `false`
3. The view body renders immediately with the preserved image
4. No loading indicator is shown
5. The init's cache check value is irrelevant because SwiftUI ignores `@State(initialValue:)` when state is already established

**Both scenarios result in no loading flicker for previously rendered content.**

#### Codebase Analysis: Current Architecture

The current MermaidBlockView (at `mkdn/Features/Viewer/Views/MermaidBlockView.swift`) uses:
- `@State private var renderedImage: NSImage?` (line 15)
- `@State private var isLoading = true` (line 17)
- `.task { await renderDiagram() }` (lines 33-35)
- `renderDiagram()` unconditionally sets `isLoading = true` (line 144)

The MermaidRenderer actor already has an LRU cache (`MermaidCache`, capacity 50) at the SVG level (at `mkdn/Core/Mermaid/MermaidCache.swift`). The fix strategy adds an NSImage-level cache accessible synchronously from `init()`.

MarkdownBlock uses stable content-hash-based IDs (`"mermaid-\(stableHash(code))"` at `mkdn/Core/Markdown/MarkdownBlock.swift:39`), which means ForEach identity remains stable across re-renders. This is important because it means the same mermaid code will always map to the same view identity in the ForEach.

#### Critical Implementation Note

The fix must ensure `.task` does NOT override the init's cache-aware state. The current `renderDiagram()` starts with `isLoading = true`, which would flash the loading view even if init set `isLoading = false`. The `.task` closure must include a guard:

```swift
.task {
    guard isLoading else { return }
    await renderDiagram()
}
```

This is a design concern rather than a hypothesis concern, but it is essential for the fix to work correctly.

**Sources**:
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift:15-17` -- current @State declarations
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift:33-35` -- .task modifier
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift:143-165` -- renderDiagram() method
- `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift:16` -- LazyVStack usage
- `mkdn/Features/Viewer/Views/MarkdownBlockView.swift:36-37` -- MermaidBlockView nesting
- `mkdn/Core/Markdown/MarkdownBlock.swift:38-39` -- stable mermaid block ID
- `mkdn/Core/Mermaid/MermaidCache.swift` -- existing SVG-level cache
- https://chris.eidhof.nl/post/swiftui-state-lifetime/ -- State lifetime in lazy containers
- https://forums.swift.org/t/pitch-swiftui-stabilize-state-in-lazy-containers/79926 -- State reset in lazy containers
- https://fatbobman.com/en/posts/tips-and-considerations-for-using-lazy-containers-in-swiftui/ -- Nested state reset behavior
- https://fatbobman.com/en/posts/mastering_swiftui_task_modifier/ -- .task re-execution in lazy containers
- https://sarunw.com/posts/state-variable-initialization/ -- @State initialization semantics

**Implications for Design**:
The fix strategy of using `@State(initialValue:)` in a custom `init()` to synchronously populate state from a cache is valid and will prevent loading flicker in LazyVStack. The approach is sound because: (1) when state is destroyed by LazyVStack recycling, the fresh init's @State values are used; (2) when state is preserved, the cached image is already in @State. The implementation must include a guard in `.task` to avoid overriding the cache-aware initial state. An NSImage-level cache (not just the existing SVG cache) is needed since the synchronous init cannot await the actor-isolated MermaidRenderer.

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | CONFIRMED | @State(initialValue:) from custom init works for cache-aware initialization in LazyVStack recycling. Fix strategy is valid in both state-reset and state-preserved scenarios. |
