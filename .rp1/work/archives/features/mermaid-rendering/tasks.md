# Development Tasks: Mermaid Diagram Rendering

**Feature ID**: mermaid-rendering
**Status**: Not Started
**Progress**: 62% (5 of 8 tasks)
**Estimated Effort**: 3 days
**Started**: 2026-02-06

## Overview

Complete the Mermaid rendering pipeline in mkdn: bounded LRU caching, robust error handling, JXContext reuse, scroll isolation via conditional ScrollView rendering, and activation-gated pan/zoom. All rendering remains fully native SwiftUI -- no WKWebView.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T4] - MermaidCache and MermaidError are independent data structures with no shared dependencies
2. [T2, T3] - MermaidRenderer uses T1 (cache) and T4 (errors); MermaidBlockView uses T4 (error display) but not T2 at the interface level
3. [T5] - Tests depend on all implementation components being complete

**Dependencies**:

- T2 -> T1 (data dependency: MermaidRenderer stores MermaidCache instance)
- T2 -> T4 (interface dependency: MermaidRenderer throws new MermaidError cases)
- T3 -> T4 (interface dependency: MermaidBlockView displays new error messages)
- T5 -> [T1, T2, T4] (test dependency: tests exercise cache, renderer, and error types)

**Critical Path**: T1 -> T2 -> T5

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Implement MermaidCache LRU struct with bounded capacity and stable DJB2 hashing `[complexity:medium]`

    **Reference**: [design.md#31-mermaidcache](design.md#31-mermaidcache)

    **Effort**: 3 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Core/Mermaid/MermaidCache.swift` contains a `MermaidCache` struct
    - [x] `get(_:)` returns cached value and promotes entry to most-recently-used
    - [x] `set(_:value:)` inserts entry and evicts least-recently-used when at capacity
    - [x] `removeAll()` clears all entries; `count` returns current entry count
    - [x] Default capacity is 50, configurable via `init(capacity:)`
    - [x] Cache keys are `UInt64` values produced by a DJB2 stable hash function
    - [x] DJB2 hash produces identical output for identical input across process launches

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Mermaid/MermaidCache.swift`
    - **Approach**: New struct with `storage: [UInt64: String]` dictionary and `accessOrder: [UInt64]` array for LRU tracking. `get` promotes to MRU, `set` evicts LRU when at capacity. DJB2 hash exposed as `mermaidStableHash(_:)` free function matching the algorithm in `MarkdownBlock.swift`.
    - **Deviations**: None
    - **Tests**: Deferred to T5

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T4**: Add new MermaidError cases for empty input, unsupported diagram type, and context creation failure `[complexity:simple]`

    **Reference**: [design.md#33-mermaiderror-enhancements](design.md#33-mermaiderror-enhancements)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `MermaidError.emptyInput` case added with user-friendly `errorDescription`
    - [x] `MermaidError.unsupportedDiagramType(String)` case added; description includes the type name
    - [x] `MermaidError.contextCreationFailed(String)` case added; description includes the underlying reason
    - [x] All existing error cases (`invalidSVGData`, `svgRenderingFailed`, `javaScriptError`) retain their current behavior
    - [x] `MermaidError` conforms to `LocalizedError` with `errorDescription` for every case

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Mermaid/MermaidRenderer.swift`
    - **Approach**: Added three new cases to the existing `MermaidError` enum with descriptive `errorDescription` strings. `emptyInput` guides user to add content, `unsupportedDiagramType` names the type and lists supported ones, `contextCreationFailed` includes the underlying reason.
    - **Deviations**: None
    - **Tests**: Deferred to T5

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### Core Implementation (Parallel Group 2)

- [x] **T2**: Enhance MermaidRenderer with LRU cache, JXContext reuse, diagram validation, and robust error wrapping `[complexity:medium]`

    **Reference**: [design.md#32-mermaidrenderer-enhancements](design.md#32-mermaidrenderer-enhancements)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] Internal `svgCache: [Int: String]` replaced with `MermaidCache(capacity: 50)`
    - [x] Cache keys use DJB2 stable hash instead of Swift `hashValue`
    - [x] `JXContext` is lazily created on first render and reused for subsequent renders
    - [x] If a JS error indicates context corruption, context is discarded and recreated on next call
    - [x] `validateDiagramType(_:)` parses first non-empty line; throws `MermaidError.unsupportedDiagramType` for known-but-unsupported types (gantt, pie, journey, gitGraph, mindmap)
    - [x] Unknown diagram type keywords are passed through to JS (not rejected)
    - [x] Empty input throws `MermaidError.emptyInput` before reaching JS evaluation
    - [x] All JS errors are wrapped as `MermaidError.javaScriptError(message)` with the original JS error message
    - [x] Resource loading uses `Bundle.module` instead of `Bundle.main` for SPM library target compatibility
    - [x] `clearCache()` public method resets the `MermaidCache`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Mermaid/MermaidRenderer.swift`
    - **Approach**: Replaced unbounded `[Int: String]` dictionary with `MermaidCache(capacity: 50)` using DJB2 stable hash keys via `mermaidStableHash()`. Added `context: JXContext?` stored property with lazy initialization in `getOrCreateContext()`; context is set to `nil` on JS errors to force recreation. Added `validateDiagramType()` that parses the first non-empty line and rejects known-but-unsupported types (gantt, pie, journey, gitGraph, mindmap) while passing unknown keywords through to JS. All JS errors caught and wrapped as `MermaidError.javaScriptError`. Empty input guarded before JS evaluation. Changed `Bundle.main` to `Bundle.module` for SPM library target resource access.
    - **Deviations**: None
    - **Tests**: Deferred to T5

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T3**: Redesign MermaidBlockView with scroll isolation, activation-gated panning, and cumulative zoom `[complexity:complex]`

    **Reference**: [design.md#34-mermaidblockview-redesign](design.md#34-mermaidblockview-redesign)

    **Effort**: 7 hours

    **Acceptance Criteria**:

    - [x] `isActivated` state controls whether a `ScrollView` is present in the view hierarchy
    - [x] When not activated: image is in a clipped container with no `ScrollView`; document scroll passes through
    - [x] When activated: image is wrapped in `ScrollView([.horizontal, .vertical])` enabling internal pan
    - [x] Tap gesture on diagram container sets `isActivated = true`
    - [x] `.onKeyPress(.escape)` sets `isActivated = false`; view is `.focusable()` when activated
    - [x] Active state displays accent-colored border as visual indicator
    - [x] Zoom uses base+delta pattern: `baseZoomScale * value.magnification` on change, `baseZoomScale = zoomScale` on end
    - [x] Zoom is clamped to range 0.5x to 4.0x
    - [x] Container has `maxHeight: 400` with `.clipped()` in non-activated state
    - [x] Loading state shows `ProgressView`; error state shows warning icon with `errorDescription` text
    - [x] Theme colors from `appState.theme.colors` are applied to container background and borders

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MermaidBlockView.swift`
    - **Approach**: Replaced always-present ScrollView with conditional rendering: inactive state uses clipped container with scaleEffect for zoom (no ScrollView, so document scroll passes through); activated state wraps image in ScrollView([.horizontal, .vertical]) with frame-based sizing for proper panning. Added @FocusState for focus management; clicking outside deactivates via onChange(of: isFocused). Zoom uses base+delta pattern (baseZoomScale * value.magnification) with clamping 0.5x-4.0x. Accent border overlay on activated state provides visual feedback. Escape key deactivates via .onKeyPress.
    - **Deviations**: In activated state, used frame-based image sizing (image.size.width * zoomScale) instead of scaleEffect to ensure ScrollView content size is correct for panning. This is functionally equivalent but gives proper scroll behavior.
    - **Tests**: SwiftUI view -- not unit-testable; verified via build + manual interaction

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### Verification (Parallel Group 3)

- [x] **T5**: Write unit tests for MermaidCache and MermaidRenderer error handling `[complexity:medium]`

    **Reference**: [design.md#t5-unit-tests](design.md#t5-unit-tests)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] New file `mkdnTests/Unit/Core/MermaidCacheTests.swift` with `@Suite("MermaidCache")`
    - [x] Test: basic get/set stores and retrieves value
    - [x] Test: cache miss returns nil
    - [x] Test: LRU eviction removes least-recently-accessed entry when at capacity
    - [x] Test: accessing an entry promotes it (prevents eviction over less-recent entries)
    - [x] Test: `removeAll()` clears all entries
    - [x] Test: DJB2 hash produces consistent results for same input across multiple calls
    - [x] New file `mkdnTests/Unit/Core/MermaidRendererTests.swift` with `@Suite("MermaidRenderer")`
    - [x] Test: empty input produces `MermaidError.emptyInput`
    - [x] Test: unsupported diagram type (e.g., "gantt") produces `MermaidError.unsupportedDiagramType`
    - [x] Test: `clearCache()` completes without error
    - [x] Tests requiring JS bundle access are marked `@Test(.disabled("Requires JS bundle in test resources"))` if `Bundle.module` resolution fails
    - [x] All tests use Swift Testing (`@Test`, `#expect`, `@Suite`), not XCTest
    - [x] `@MainActor` applied to individual test functions (not `@Suite` struct) when testing actor-isolated types

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Core/MermaidCacheTests.swift`, `mkdnTests/Unit/Core/MermaidRendererTests.swift`
    - **Approach**: MermaidCacheTests (10 tests): covers get/set, cache miss, LRU eviction, access promotion, removeAll, count tracking, DJB2 hash consistency/distinctness, default capacity with overflow eviction, and key overwrite. MermaidRendererTests (11 tests): covers empty input error, whitespace-only input error, unsupported type errors (gantt, pie, parameterized for all 5 types), clearCache, and error description messages for all MermaidError cases. Tests create fresh MermaidRenderer instances to avoid shared state. No JS bundle tests needed disabling -- all validation/error tests pass without JS context.
    - **Deviations**: Added extra tests beyond minimum spec: overwrite-existing-key, count tracking, hash distinctness, whitespace-only input, parameterized test for all 5 unsupported types, error description tests for all MermaidError cases. No `@MainActor` needed since `MermaidRenderer` is a plain actor (not `@MainActor`); async suffices.
    - **Tests**: 21/21 passing (10 cache + 11 renderer)

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

### User Docs

- [ ] **TD1**: Update modules.md - Core Layer > Mermaid `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer > Mermaid

    **KB Source**: modules.md:Core/Mermaid

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] `MermaidCache.swift` added to the Core/Mermaid module inventory table with purpose "LRU cache: bounded SVG string cache with stable DJB2 hashing"

- [ ] **TD2**: Update architecture.md - Mermaid Diagrams pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Mermaid Diagrams pipeline

    **KB Source**: architecture.md:Mermaid Diagrams

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] LRU caching strategy documented (capacity 50, DJB2 keys, eviction policy)
    - [ ] JXContext reuse strategy documented (lazy singleton, error-triggered recreation)
    - [ ] Scroll isolation approach documented (conditional ScrollView rendering, click-to-activate)

- [ ] **TD3**: Update patterns.md - Actor Pattern (Mermaid) `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Actor Pattern (Mermaid)

    **KB Source**: patterns.md:Actor Pattern

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] LRU cache pattern added (internal struct, no Sendable needed inside actor)
    - [ ] Scroll isolation pattern added (conditional ScrollView rendering for gesture control)
    - [ ] Base+delta zoom pattern added as recommended MagnifyGesture usage

## Acceptance Criteria Checklist

### FR-MER-001: Mermaid Block Detection
- [ ] A fenced code block tagged with ` ```mermaid ` is identified as a Mermaid block
- [ ] The raw Mermaid source text is extracted and passed to the rendering pipeline
- [ ] Non-mermaid code blocks are unaffected and continue to render as syntax-highlighted code

### FR-MER-002: Mermaid-to-SVG Conversion
- [ ] Valid flowchart Mermaid syntax produces a well-formed SVG string
- [ ] Valid sequence diagram syntax produces a well-formed SVG string
- [ ] Valid state diagram syntax produces a well-formed SVG string
- [ ] Valid class diagram syntax produces a well-formed SVG string
- [ ] Valid ER diagram syntax produces a well-formed SVG string
- [ ] The JavaScript execution occurs entirely in-process with no network calls or external processes

### FR-MER-003: SVG-to-Native-Image Rasterization
- [ ] A valid SVG string is rasterized into a displayable native image
- [ ] The resulting image preserves visual fidelity of the original SVG
- [ ] The image is displayed inline within the Markdown document at the position of the original Mermaid code block

### FR-MER-004: Rendering State UI
- [ ] A loading spinner is displayed while rendering is in progress
- [ ] On successful render, the spinner is replaced by the rendered diagram image
- [ ] On render failure, a warning icon and a human-readable error message are displayed
- [ ] The error message includes enough context to help the user identify the problem

### FR-MER-005: SVG Cache
- [ ] Rendering the same Mermaid source text a second time returns the cached SVG without re-executing JavaScript
- [ ] Changing the Mermaid source text (even by one character) results in a cache miss and a fresh render
- [ ] The cache has a bounded size with an eviction policy to prevent unbounded memory growth
- [ ] A cache-clearing capability exists that forces all diagrams to re-render on next display

### FR-MER-006: Pinch-to-Zoom
- [ ] A pinch gesture on a rendered diagram increases or decreases the magnification level
- [ ] Magnification is clamped to the range 0.5x (minimum) to 4.0x (maximum)
- [ ] Zoom level persists while the diagram is displayed (does not reset on re-layout)
- [ ] The zoom gesture feels smooth and responsive with no visible lag

### FR-MER-007: Two-Finger Scroll/Pan
- [ ] Two-finger scrolling within an activated diagram pans the view horizontally and vertically
- [ ] The diagram must be explicitly activated (clicked) before internal scrolling is enabled
- [ ] Panning is bounded to the content area of the diagram

### FR-MER-008: Scroll Isolation
- [ ] Scrolling the Markdown document moves the document, not the contents of a Mermaid diagram
- [ ] A Mermaid diagram that is partially visible does not trap or redirect scroll momentum
- [ ] Only after the user explicitly clicks a diagram does it capture scroll input for internal panning
- [ ] Clicking outside the diagram or pressing Escape deactivates diagram-internal scrolling

### FR-MER-009: Theme-Aware Diagram Containers
- [ ] The diagram container background uses the active theme's secondary background color
- [ ] Text labels and borders use the active theme's secondary foreground color
- [ ] Switching themes updates diagram container colors without requiring a re-render of the diagram image

### FR-MER-010: Graceful Error Handling
- [ ] Malformed Mermaid syntax produces an error state view, not a crash
- [ ] JavaScript execution errors produce an error state view with the JS error message
- [ ] SVG rasterization failures produce an error state view
- [ ] Empty Mermaid code blocks produce an appropriate error or empty state, not a crash

## Definition of Done

- [ ] All tasks completed (T1, T2, T3, T4, T5, TD1, TD2, TD3)
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
- [ ] `swift build` succeeds without errors
- [ ] `swift test` passes all new and existing tests
- [ ] `swiftlint lint` reports no violations
- [ ] `swiftformat .` produces no changes
