# Development Tasks: Fix Infinite Scroll Re-render Loop

**Feature ID**: fix-infinite-scroll-rerender
**Status**: Not Started
**Progress**: 70% (7 of 10 tasks)
**Estimated Effort**: 2.5 days
**Started**: 2026-02-06

## Overview

Break the self-sustaining re-render loop triggered by scrolling through Mermaid diagram blocks in the LazyVStack-based preview. The fix introduces a `@MainActor` NSImage cache (`MermaidImageStore`) that survives view recycling, enables synchronous cache-aware initialization in MermaidBlockView, hardens ImageBlockView against the same pattern, and stabilizes ListItem identity to prevent cascading ID instability.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T3, T4] - T1 is a new standalone class, T3 modifies ImageBlockView independently, T4 modifies MarkdownBlock independently
2. [T2, T5] - T2 consumes T1 (MermaidImageStore), T5 wires cache invalidation (uses T1)

**Dependencies**:

- T2 -> T1 (interface: MermaidBlockView calls MermaidImageStore.shared)
- T5 -> T1 (interface: AppState/MarkdownPreviewView calls MermaidImageStore.shared.removeAll())

**Critical Path**: T1 -> T2

## Task Breakdown

### Independent Foundation (Parallel Group 1)

- [x] **T1**: Create MermaidImageStore -- `@MainActor` singleton with LRU NSImage cache `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Mermaid/MermaidImageStore.swift`
    - **Approach**: Created `@MainActor final class` with LRU NSImage cache following the existing `MermaidCache` struct pattern; keyed by `mermaidStableHash`, capacity 50, with `get`/`store`/`removeAll` API
    - **Deviations**: None
    - **Tests**: Build clean, lint clean, all existing tests pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

    **Reference**: [design.md#31-mermaidimagestore-new](design.md#31-mermaidimagestore-new)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Core/Mermaid/MermaidImageStore.swift` exists
    - [x] Class is `@MainActor final class` with `static let shared` singleton
    - [x] `get(_ code: String) -> NSImage?` returns cached image or nil (synchronous)
    - [x] `store(_ code: String, image: NSImage)` adds image to cache (synchronous)
    - [x] `removeAll()` clears entire cache
    - [x] LRU eviction triggers when storage exceeds capacity of 50
    - [x] Uses `mermaidStableHash` (existing DJB2 utility) for cache keys
    - [x] Builds without warnings under `swift build`

- [x] **T3**: Harden ImageBlockView against scroll re-render -- `.task(id:)` and early return `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/ImageBlockView.swift`
    - **Approach**: Changed `.task` to `.task(id: source)` to prevent re-firing when parent body re-evaluates without content change; added early-return guard in `loadImage()` that skips all work when `loadedImage` is already set or `loadError` is true
    - **Deviations**: None
    - **Tests**: Build clean, lint clean, all existing tests pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

    **Reference**: [design.md#33-imageblockview-refactor](design.md#33-imageblockview-refactor)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `.task` replaced with `.task(id: source)` in ImageBlockView
    - [x] `loadImage()` has early-return guard when `loadedImage` is already set
    - [x] Images that have loaded do not re-trigger loading when view is recycled by LazyVStack
    - [x] Existing image loading behavior for first render is unchanged

- [x] **T4**: Stabilize ListItem identity with content-derived IDs `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownBlock.swift`
    - **Approach**: Replaced `let id = UUID()` with computed `var id: String` that derives identity from child block IDs via `"li-\(blocks.map(\.id).joined(separator: "-"))"`, ensuring stable identity across consecutive parse passes
    - **Deviations**: None
    - **Tests**: Build clean, lint clean, all existing tests pass (including deterministic ID tests in MarkdownVisitorTests)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

    **Reference**: [design.md#34-listitem-id-stability-fix](design.md#34-listitem-id-stability-fix)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `ListItem.id` is a computed property derived from child block IDs (not `UUID()`)
    - [x] Same content produces same ID across consecutive parse passes
    - [x] Different content produces different IDs
    - [x] No regression in list rendering behavior

### Integration (Parallel Group 2 -- depends on T1)

- [x] **T2**: Refactor MermaidBlockView with cache-aware init and `.task(id:)` `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MermaidBlockView.swift`
    - **Approach**: Added `@MainActor init(code:)` with synchronous `MermaidImageStore.shared.get(code)` lookup; initializes `@State` properties from cache (renderedImage, isLoading) so recycled views start in rendered state; changed `.task` to `.task(id: code)` to prevent re-firing on parent body re-evaluation; added early-return guard in `renderDiagram()` when renderedImage or errorMessage already set; stores NSImage to MermaidImageStore after successful render
    - **Deviations**: None
    - **Tests**: Build clean, lint clean, all existing tests pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

    **Reference**: [design.md#32-mermaidblockview-refactor](design.md#32-mermaidblockview-refactor)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] Custom `init(code:)` performs synchronous cache lookup via `MermaidImageStore.shared.get(code)`
    - [x] `@State` properties (`renderedImage`, `isLoading`) initialized from cache on hit
    - [x] `.task` replaced with `.task(id: code)`
    - [x] `renderDiagram()` has early-return guard when `renderedImage` is already set
    - [x] Successful render stores NSImage via `MermaidImageStore.shared.store(code, image:)`
    - [x] Cache hit path: no async work, no state transitions, no layout changes
    - [x] Cache miss path: loading indicator shown, then diagram rendered (existing behavior preserved)
    - [x] Existing zoom/pan/activation behavior unchanged

- [x] **T5**: Wire cache invalidation in AppState and MarkdownPreviewView `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/App/AppState.swift`, `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`
    - **Approach**: Added `MermaidImageStore.shared.removeAll()` in `loadFile(at:)` (clears cached images on file reload) and in `.onChange(of: appState.theme)` (clears cached images before re-rendering blocks on theme change); no existing `MermaidRenderer.shared.clearCache()` calls exist in app code so co-location AC is N/A
    - **Deviations**: None
    - **Tests**: Build clean, lint clean, all 102 existing tests pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | N/A |
    | Comments | PASS |

    **Reference**: [design.md#35-cache-invalidation](design.md#35-cache-invalidation)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `MermaidImageStore.shared.removeAll()` called in `AppState.loadFile(at:)` on file reload
    - [x] `MermaidImageStore.shared.removeAll()` called in `.onChange(of: appState.theme)` in MarkdownPreviewView
    - [x] Cache invalidation co-located with any existing `MermaidRenderer.shared.clearCache()` calls
    - [x] Theme change followed by scroll shows freshly rendered diagrams (not stale cached images)
    - [x] File reload followed by scroll shows freshly rendered diagrams

### Testing

- [x] **T6**: Write MermaidImageStore unit tests `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Core/MermaidImageStoreTests.swift`
    - **Approach**: Created 9 unit tests covering all LRU cache behaviors: cache miss, store/get, identity preservation, different-code miss, overwrite, LRU eviction, access promotion, removeAll, and count tracking; all test functions annotated with `@MainActor` per Swift 6 + `@Observable` testing pattern
    - **Deviations**: None
    - **Tests**: 9/9 passing (110 total tests pass)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] New file `mkdnTests/Unit/Core/MermaidImageStoreTests.swift` exists
    - [x] Uses Swift Testing framework (`@Suite`, `@Test`, `#expect`)
    - [x] Test functions annotated with `@MainActor` (not the `@Suite` struct)
    - [x] Tests cover: cache miss returns nil, basic store/get cycle, LRU eviction at capacity, `removeAll` clears cache, same code returns same cached instance, different code produces miss
    - [x] All tests pass under `swift test`

- [x] **T7**: Write ListItem ID stability tests `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Core/MarkdownBlockTests.swift`
    - **Approach**: Created new test file with `@Suite("MarkdownBlock")` containing 2 tests that verify ListItem content-derived ID stability: same content produces same ID across instances, different content produces different IDs
    - **Deviations**: None
    - **Tests**: 2/2 passing (112 total tests pass)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] Tests added to `mkdnTests/Unit/Core/MarkdownBlockTests.swift` (new or extended)
    - [x] Uses Swift Testing framework (`@Test`, `#expect`)
    - [x] Tests cover: same content produces same ID, different content produces different IDs
    - [x] All tests pass under `swift test`

### User Docs

- [ ] **TD1**: Create documentation for MermaidImageStore - Mermaid module `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `.rp1/context/modules.md`

    **Section**: Mermaid module

    **KB Source**: `architecture.md:#mermaid-diagrams`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New MermaidImageStore component documented in Mermaid module section of modules.md
    - [ ] Documents role as @MainActor NSImage LRU cache in the rendering pipeline

- [ ] **TD2**: Update Mermaid Diagrams pipeline description `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Mermaid Diagrams pipeline

    **KB Source**: `architecture.md:#rendering-pipeline`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] MermaidImageStore layer added to the rendering pipeline description
    - [ ] Pipeline diagram/description shows MermaidImageStore between view and MermaidRenderer

- [ ] **TD3**: Update Anti-Patterns with LazyVStack cache-aware init pattern `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Anti-Patterns

    **KB Source**: `patterns.md:#anti-patterns`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Pattern note added: "Use cache-aware init for views in LazyVStack that perform async work"
    - [ ] Documents the problem (re-render loop) and solution (synchronous cache check in init)

## Acceptance Criteria Checklist

### REQ-001: Break the Scroll Re-render Cycle
- [ ] AC-1a: Scrolling up and down through a document with 5+ Mermaid blocks at normal speed produces no visible re-rendering of already-rendered diagrams
- [ ] AC-1b: Scrolling rapidly (fast flick gesture) through the same document does not cause the app to become unresponsive
- [ ] AC-1c: Scrolling rapidly does not cause the app to crash

### REQ-002: Preserve Rendered Mermaid Output Across View Recycling
- [ ] AC-2a: A Mermaid diagram that was fully rendered, then scrolled off-screen, then scrolled back on-screen, appears immediately without a loading indicator
- [ ] AC-2b: The JavaScriptCore/SVG rendering pipeline is not re-invoked for a Mermaid block whose content has not changed

### REQ-003: Stable View Identity for Mermaid Blocks
- [ ] AC-3a: The Identifiable conformance for Mermaid blocks produces the same ID for the same Mermaid source code across consecutive render passes
- [ ] AC-3b: No .task or .onAppear re-fires for a Mermaid block that has not changed content while the user is only scrolling

### REQ-004: No Degradation of Initial Mermaid Render Experience
- [ ] AC-4a: Opening a file with Mermaid blocks shows loading indicators that resolve to rendered diagrams
- [ ] AC-4b: Editing Mermaid source code in side-by-side mode triggers a fresh render of the changed diagram

### REQ-005: No Scroll Re-render Issues in Side-by-Side Mode
- [ ] AC-5a: Scrolling through Mermaid-containing content in side-by-side mode does not trigger visible re-render loops or jank

### REQ-006: Non-Mermaid Block Stability During Scroll
- [ ] AC-6a: Images that have already loaded do not show a loading placeholder when scrolled back into view
- [ ] AC-6b: Code blocks do not visibly re-highlight when scrolled back into view

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] Docs updated
