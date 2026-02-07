# Development Tasks: Mermaid Gesture Interaction

**Feature ID**: mermaid-gesture-interaction
**Status**: Not Started
**Progress**: 62% (5 of 8 tasks)
**Estimated Effort**: 2.5 days
**Started**: 2026-02-06

## Overview

Replace the click-to-activate / Escape-to-deactivate interaction model on MermaidBlockView with a momentum-aware gesture system. Uses NSEvent scroll wheel phases to classify user intent per-event, forwarding document scrolls and consuming diagram pans. No visible mode switching, no activation borders, no scroll traps.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2, T3] - T1 (classifier), T2 (pan state), and T3 (monitor view) have no data or interface dependencies on each other. T3 will use T1 and T2 internally, but can be built with stub types initially since the interfaces are defined upfront.
2. [T4, T5] - T4 (view refactor) integrates all three components; T5 (tests) validates T1 and T2 logic.

**Dependencies:**

- T4 -> [T1, T2, T3] (integration: T4 composes all three components into MermaidBlockView)
- T5 -> [T1, T2] (test target: T5 tests the classifier and pan state structs)

**Critical Path:** T1 -> T4

## Task Breakdown

### Core Gesture Components

- [x] **T1**: Implement GestureIntentClassifier struct `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Gesture/GestureIntentClassifier.swift`
    - **Approach**: Pure struct with `Verdict` (.panDiagram/.passThrough) and `GestureState` (.idle/.panning/.passingThrough) enums. `classify(phase:momentumPhase:contentFitsInFrame:)` implements the full decision table using NSEvent.Phase fields directly for testability (D4). Momentum -> passThrough (BR-03); began -> panDiagram (BR-02); began with contentFitsInFrame -> passThrough (BR-05); changed without prior began -> passThrough (BR-01); ended/cancelled -> reset to idle.
    - **Deviations**: None
    - **Tests**: Deferred to T5

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

    **Reference**: [design.md#31-gestureintentclassifier](design.md#31-gestureintentclassifier)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] File created at `mkdn/Core/Gesture/GestureIntentClassifier.swift`
    - [x] Struct exposes `Verdict` enum with `.panDiagram` and `.passThrough` cases
    - [x] Struct exposes `GestureState` enum with `.idle`, `.panning`, `.passingThrough` cases
    - [x] `classify(_:contentFitsInFrame:)` mutating method implements the full decision table: momentum events produce `.passThrough` (BR-03); `phase == .began` over diagram produces `.panDiagram` (BR-02); gesture started outside stays `.passThrough` (BR-01); content fits in frame always `.passThrough` (BR-05)
    - [x] Gesture state resets on `.ended` or `.cancelled` phase
    - [x] Verdict is sticky within a gesture sequence (`.changed` events follow the verdict set at `.began`)
    - [x] Accepts extracted event fields (phase, momentumPhase, contentFitsInFrame) rather than raw NSEvent for testability (D4)

- [x] **T2**: Implement DiagramPanState struct `[complexity:simple]`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Gesture/DiagramPanState.swift`
    - **Approach**: Pure value-type struct tracking `offset: CGSize`. `applyDelta` computes maxOffset per axis from `(contentSize * zoomScale - frameSize) / 2`, clamps the proposed offset, and returns an `ApplyResult` splitting consumed vs. overflow deltas. When content fits in frame, maxOffset is zero so all delta overflows (BR-05 structural). Only imports Foundation.
    - **Deviations**: None
    - **Tests**: Deferred to T5

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

    **Reference**: [design.md#32-diagrampanstate](design.md#32-diagrampanstate)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] File created at `mkdn/Core/Gesture/DiagramPanState.swift`
    - [x] Struct tracks `offset: CGSize` initialized to `.zero`
    - [x] `applyDelta(dx:dy:contentSize:frameSize:zoomScale:)` returns `ApplyResult` with `consumedDelta` and `overflowDelta`
    - [x] Boundary clamping: `maxOffsetX = max(0, (contentSize.width * zoomScale - frameSize.width) / 2)`, same for Y
    - [x] When content fits in frame at current zoom, all delta is overflow (BR-05 structural)
    - [x] Overflow delta is the excess beyond the boundary, enabling seamless edge-overflow to document scroll (FR-03)
    - [x] Pure arithmetic, no dependencies, no side effects

- [x] **T3**: Implement ScrollPhaseMonitor NSViewRepresentable `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Components/ScrollPhaseMonitor.swift`
    - **Approach**: `ScrollPhaseMonitorView` (NSView subclass) overrides `scrollWheel(with:)` and delegates to an `onScrollEvent` closure. `ScrollPhaseMonitor` (NSViewRepresentable) uses a `@MainActor Coordinator` that owns a `GestureIntentClassifier` and `DiagramPanState`. Coordinator computes aspect-fit content size from raw image size and NSView bounds, checks `contentFitsInFrame`, classifies events via the classifier, applies pan deltas or forwards via `nextResponder`. Overflow from pan boundary triggers event forwarding (FR-03). `updateNSView` syncs coordinator state and detects external panOffset resets.
    - **Deviations**: None
    - **Tests**: Not applicable (NSView lifecycle; categorized as AVOID in test plan)

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

    **Reference**: [design.md#33-scrollphasemonitor-nsviewrepresentable](design.md#33-scrollphasemonitor-nsviewrepresentable)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] File created at `mkdn/UI/Components/ScrollPhaseMonitor.swift`
    - [x] `ScrollPhaseMonitorView` NSView subclass overrides `scrollWheel(with:)` and delegates to `onScrollEvent` closure without calling `super`
    - [x] `ScrollPhaseMonitor` NSViewRepresentable with Coordinator that owns a `GestureIntentClassifier` and `DiagramPanState`
    - [x] Coordinator translates NSEvent fields (phase, momentumPhase, scrollingDeltaX/Y) to classifier inputs
    - [x] On `.panDiagram` verdict: applies delta to DiagramPanState, updates `panOffset` binding
    - [x] On `.passThrough` verdict: forwards event via `nextResponder?.scrollWheel(with: event)`
    - [x] On overflow from DiagramPanState: forwards event to nextResponder for document scroll (FR-03)
    - [x] Accepts `contentSize`, `zoomScale`, and `panOffset` binding from parent view
    - [x] Follows existing `WindowAccessor` / `WindowAccessorView` NSViewRepresentable pattern
    - [x] Does not override `magnify(with:)` so pinch-to-zoom passes through naturally (FR-04)

### Integration

- [x] **T4**: Refactor MermaidBlockView to use momentum gesture system `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/MermaidBlockView.swift`
    - **Approach**: Removed dual-mode architecture (isActivated/isFocused, activatedDiagramView/inactiveDiagramView, DragGesture, onTapGesture, onKeyPress, accent border). Replaced with single `diagramView(image:)` using GeometryReader + ScrollPhaseMonitor overlay for momentum-aware panning and `panOffset` @State. Retained zoom gesture, rendering pipeline, loading/error views, and cache unchanged. 204 -> 154 lines (net -50).
    - **Deviations**: None
    - **Tests**: N/A (integration task; component tests in T5)

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

    **Reference**: [design.md#34-mermaidblockview-refactor](design.md#34-mermaidblockview-refactor)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] Removed: `isActivated` state, `isFocused` FocusState, `activatedDiagramView`, `inactiveDiagramView`, `onTapGesture` activation, `onKeyPress(.escape)` deactivation, accent border overlay, `panGesture` DragGesture
    - [x] Retained: `renderedImage`, `errorMessage`, `isLoading`, `zoomScale`, `baseZoomScale`, `renderDiagram()`, `svgStringToImage()`, `zoomGesture` (MagnifyGesture), loading/error views, MermaidImageStore cache
    - [x] Added: `panOffset: CGSize` @State (replaces `dragOffset` + `baseDragOffset`)
    - [x] Added: `ScrollPhaseMonitor` overlay on the diagram image with contentSize, zoomScale, and panOffset binding
    - [x] Added: `GeometryReader` to measure frame size for boundary calculations
    - [x] Single unified `diagramView(image:)` code path (no conditional activated/inactive branching) (D5)
    - [x] View structure matches design: Image -> scaleEffect -> offset -> frame -> clipped -> overlay(ScrollPhaseMonitor) -> gesture(zoomGesture)
    - [x] No visible activation indicator (border, glow, outline) at any time (FR-05, AC-05a/b/c)
    - [x] Each diagram instance independently tracks its own panOffset and zoomScale (FR-07, AC-07a)
    - [x] Net reduction in lines of code

### Testing

- [x] **T5**: Write unit tests for GestureIntentClassifier and DiagramPanState `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdnTests/Unit/Core/GestureIntentClassifierTests.swift`, `mkdnTests/Unit/Core/DiagramPanStateTests.swift`
    - **Approach**: 18 tests total (10 classifier, 8 pan state) using Swift Testing. Classifier tests cover all decision table rows: fresh began -> pan, momentum -> passThrough, changed-without-began -> passThrough (BR-01), contentFitsInFrame -> passThrough (BR-05), sticky verdicts through changed events, reset on ended/cancelled, and mayBegin fallback. Pan state tests cover within-bounds consumption, positive/negative boundary overflow, content-smaller-than-frame all-overflow (BR-05), zoom scale boundary effects, successive delta accumulation, mixed-axis independent clamping, and initial offset.
    - **Deviations**: None
    - **Tests**: 18/18 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | PASS |
    | Commit | N/A |
    | Comments | PASS |

    **Reference**: [design.md#t5-unit-tests](design.md#t5-unit-tests)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] File created at `mkdnTests/Unit/Core/GestureIntentClassifierTests.swift` using Swift Testing (`@Suite`, `@Test`, `#expect`)
    - [x] Test: Fresh gesture over diagram produces `.panDiagram` (BR-02, AC-01a)
    - [x] Test: Momentum event produces `.passThrough` (BR-03, AC-01c)
    - [x] Test: Gesture started outside stays `.passThrough` through `.changed` (BR-01, AC-01b)
    - [x] Test: Content fits in frame always produces `.passThrough` (BR-05, AC-03f)
    - [x] Test: Gesture sequence resets on `.ended`, next `.began` classified fresh
    - [x] Test: Pan gesture stays pan through `.changed` events (sticky verdict)
    - [x] Test: Pass-through stays pass-through through `.changed` events (sticky verdict)
    - [x] File created at `mkdnTests/Unit/Core/DiagramPanStateTests.swift` using Swift Testing
    - [x] Test: Delta within bounds consumed fully, overflow is zero (FR-02, AC-02a)
    - [x] Test: Delta at boundary produces overflow (FR-03, AC-03a/b)
    - [x] Test: Content smaller than frame produces all overflow (BR-05)
    - [x] Test: Negative and positive boundary clamping both directions (AC-03c/d)
    - [x] Test: Zoom scale affects pannable boundary (FR-04, AC-04d)
    - [x] All tests pass with `swift test`

### User Docs

- [ ] **TD1**: Update architecture.md - Mermaid Diagrams rendering pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Mermaid Diagrams rendering pipeline

    **KB Source**: architecture.md:Mermaid Diagrams

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section reflects removal of click-to-activate model and addition of momentum-based gesture system
    - [ ] Describes ScrollPhaseMonitor overlay, GestureIntentClassifier, and DiagramPanState roles in the interaction flow
    - [ ] No references to activation state, focus handling, or Escape-to-deactivate

- [ ] **TD2**: Update modules.md - Core Layer, Features Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer, Features Layer

    **KB Source**: modules.md:Core Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Core Layer section includes `Core/Gesture/` module with GestureIntentClassifier and DiagramPanState
    - [ ] UI/Components section includes ScrollPhaseMonitor
    - [ ] Dependency relationships documented (ScrollPhaseMonitor depends on GestureIntentClassifier and DiagramPanState)

- [ ] **TD3**: Update patterns.md - NSViewRepresentable event interception pattern `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: (new section)

    **KB Source**: patterns.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New section documents NSViewRepresentable event interception pattern
    - [ ] Covers NSView subclass with event override, Coordinator as state holder, responder chain forwarding
    - [ ] References ScrollPhaseMonitor as canonical example alongside existing WindowAccessor pattern

## Acceptance Criteria Checklist

### FR-01: Momentum-Based Intent Detection
- [ ] AC-01a: Fresh two-finger scroll over stationary cursor pans diagram
- [ ] AC-01b: Gesture begun outside diagram continues document scroll
- [ ] AC-01c: Momentum-phase scroll passes through to document
- [ ] AC-01d: Intent detection is imperceptible (no delay, flicker, hesitation)

### FR-02: Fresh Gesture Panning
- [ ] AC-02a: Panning works in both horizontal and vertical directions simultaneously
- [ ] AC-02b: Panning is smooth and responsive with no perceptible lag
- [ ] AC-02c: Content moves in natural scroll direction (macOS conventions)
- [ ] AC-02d: Panning works on all five supported diagram types

### FR-03: Edge Overflow to Document Scroll
- [ ] AC-03a: Top edge overflow scrolls document upward
- [ ] AC-03b: Bottom edge overflow scrolls document downward
- [ ] AC-03c: Left edge overflow scrolls document leftward
- [ ] AC-03d: Right edge overflow scrolls document rightward
- [ ] AC-03e: Transition from panning to document scroll is seamless
- [ ] AC-03f: Content smaller than frame passes all scrolls through

### FR-04: Pinch-to-Zoom Always Active
- [ ] AC-04a: Pinch-to-zoom works immediately without activation
- [ ] AC-04b: Zoom clamped to 0.5x - 4.0x
- [ ] AC-04c: Zooming does not interfere with document scrolling
- [ ] AC-04d: Zooming in enables panning on now-larger content
- [ ] AC-04e: Zooming out to fit causes scroll pass-through

### FR-05: No Visible Activation State
- [ ] AC-05a: No border/outline/glow during panning
- [ ] AC-05b: No border/outline/glow during zooming
- [ ] AC-05c: Diagram visually identical regardless of interaction state

### FR-06: Document Scroll Continuity
- [ ] AC-06a: Scrolling at any speed never causes scroll trap at diagram boundary
- [ ] AC-06b: Multiple consecutive diagrams cause no scroll interruption
- [ ] AC-06c: Momentum scrolling carries through diagrams
- [ ] AC-06d: Scroll direction reversal over diagram causes no capture

### FR-07: Multiple Diagrams in Document
- [ ] AC-07a: Each diagram independently tracks pan offset and zoom level
- [ ] AC-07b: Scrolling between adjacent diagrams causes no capture
- [ ] AC-07c: User can pan one diagram, scroll to another, pan that independently

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
- [ ] `swift build` succeeds
- [ ] `swift test` passes (including new T5 tests)
- [ ] SwiftLint passes
- [ ] SwiftFormat applied
