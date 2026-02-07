# Requirements Specification: Mermaid Gesture Interaction

**Feature ID**: mermaid-gesture-interaction
**Parent PRD**: [Mermaid Rendering](../../prds/mermaid-rendering.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

Replace the current click-to-activate interaction model on Mermaid diagrams with a momentum-aware gesture system that invisibly distinguishes between "user intends to pan this chart" and "user is scrolling the document and happens to pass over a chart." The interaction must feel completely natural -- as if the app reads the user's mind -- with no visible mode switching, no activation indicators, and no interruption to document-level scrolling.

## 2. Business Context

### 2.1 Problem Statement

The current Mermaid diagram interaction requires users to click a diagram to activate internal panning, then press Escape or click outside to deactivate. This two-step activation model is unnatural and creates friction: users must consciously switch modes before they can explore a diagram, and they must consciously switch back before they can resume scrolling the document. The interaction draws attention to itself rather than disappearing into the background.

Worse, the current model creates a trap: if a user forgets they activated a diagram, their next scroll attempt is captured by the diagram instead of moving the document. This is jarring and breaks the flow of reading.

### 2.2 Business Value

Mermaid diagram interaction is called out in the project charter as a key differentiator: "first-class Mermaid chart rendering with native gestures (pinch-to-zoom, two-finger scroll)." The charter's design philosophy demands that every interactive element be crafted with obsessive attention -- "no element is too small to get right." A gesture system that feels invisible and intuitive directly serves the product's core value proposition of beauty and simplicity.

Getting this right transforms diagrams from "content you can interact with if you remember the activation ritual" into "content that just responds to what you're obviously trying to do."

### 2.3 Success Metrics

- **Zero scroll traps**: A user scrolling through a long document with multiple Mermaid diagrams never has their scroll captured or interrupted by a diagram they are passing over.
- **Zero-friction panning**: A user who wants to explore a specific diagram can do so immediately with a two-finger gesture, without any click, tap, or other activation step.
- **Invisible intent detection**: The user never perceives the system making a decision about their intent. The right thing just happens.
- **Charter alignment**: The interaction passes the charter's "designed by someone who cares about the difference between good enough and perfect" test.

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Interaction Pattern |
|-----------|-------------|---------------------|
| Document Reader | Developer reading a Markdown document containing Mermaid diagrams, scrolling top-to-bottom | Scrolls through document at varying speeds; diagrams are inline content they pass over |
| Diagram Explorer | Same developer, but now interested in a specific diagram's details | Hovers cursor over a diagram, then uses two-finger scroll to pan within it; may also pinch-to-zoom |

These are the same person in different moments. The system must seamlessly serve both modes without the user having to announce which mode they are in.

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator | Daily-driver quality: the gesture system must feel right every single time, or it becomes a source of daily irritation |
| Charter | Design philosophy compliance: invisible, intuitive, obsessively crafted |

## 4. Scope Definition

### 4.1 In Scope

- Momentum-based intent detection for two-finger scroll gestures over Mermaid diagrams
- Replacing the current click-to-activate / Escape-to-deactivate interaction model
- Edge-overflow behavior: panning within a diagram that reaches the content boundary overflows to document scroll
- Pinch-to-zoom always active when cursor hovers over a diagram (no intent detection needed for zoom)
- Removal of the visible "activated" state border/outline on diagrams
- All five supported diagram types (flowchart, sequence, state, class, ER)

### 4.2 Out of Scope

- Changes to the Mermaid rendering pipeline (JavaScriptCore, SVG, SwiftDraw)
- Changes to diagram caching or error handling
- New diagram types
- Keyboard-based diagram navigation
- Touch Bar or accessibility-specific interaction modes (future feature)
- Click-to-interact as an alternative activation path (the new gesture system fully replaces it)

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A1 | The macOS trackpad/scroll event system exposes enough information (momentum phase, gesture phase) to reliably distinguish fresh gestures from momentum-carry scrolls | The core intent detection model would need to be rethought; may require lower-level event monitoring |
| A2 | SwiftUI's gesture system (or NSEvent monitoring at the view level) can intercept scroll events before they reach a parent ScrollView, allowing conditional forwarding | May require dropping to AppKit for scroll event interception |
| A3 | Magic Mouse two-finger scrolling produces the same event phases as trackpad scrolling | May need separate handling for Magic Mouse vs. trackpad |
| A4 | Edge-overflow from an inner scroll context to an outer scroll context is achievable without re-implementing scroll physics | May need custom momentum simulation at the boundary |

## 5. Functional Requirements

### FR-01: Momentum-Based Intent Detection
**Priority**: Must Have
**Actor**: Document Reader / Diagram Explorer
**Requirement**: When a two-finger scroll gesture occurs while the cursor is over a Mermaid diagram, the system must determine whether the gesture is a "fresh" gesture (user intends to pan the diagram) or a "momentum-carry" gesture (user was scrolling the document and the cursor passed over the diagram due to momentum or continuous scrolling).
**Rationale**: This is the core interaction problem. Without reliable intent detection, the system either traps document scrolls (current broken behavior) or never allows diagram panning (opposite broken behavior).
**Acceptance Criteria**:
- AC-01a: A fresh two-finger scroll gesture initiated while the cursor is stationary over a Mermaid diagram pans the diagram content.
- AC-01b: A two-finger scroll gesture that began outside a Mermaid diagram and continues into/over the diagram area continues scrolling the document without interruption.
- AC-01c: A momentum-phase scroll (the coasting phase after the user lifts fingers from the trackpad) that carries over a Mermaid diagram passes through to the document scroll without being captured.
- AC-01d: Intent detection is imperceptible to the user -- there is no visible delay, flicker, or hesitation.

### FR-02: Fresh Gesture Panning
**Priority**: Must Have
**Actor**: Diagram Explorer
**Requirement**: When a fresh two-finger scroll gesture is detected over a Mermaid diagram, the diagram content pans in the direction of the gesture, allowing the user to explore all areas of the diagram within its visible frame.
**Rationale**: Panning is the primary interaction for exploring large or detailed diagrams that exceed their visible frame.
**Acceptance Criteria**:
- AC-02a: Panning works in both horizontal and vertical directions simultaneously.
- AC-02b: Panning is smooth and responsive, with no perceptible lag between gesture input and diagram movement.
- AC-02c: The diagram content moves in the natural scroll direction (content follows the finger movement direction, consistent with macOS trackpad conventions).
- AC-02d: Panning works on all five supported diagram types.

### FR-03: Edge Overflow to Document Scroll
**Priority**: Must Have
**Actor**: Diagram Explorer
**Requirement**: When a user is panning within a Mermaid diagram and reaches the edge of the diagram content in the direction of their gesture, continued scrolling in that direction must overflow and resume scrolling the parent document.
**Rationale**: Preventing dead-end scroll traps. The user should never feel "stuck" inside a diagram. This matches the behavior of embedded scroll views in most well-designed macOS applications.
**Acceptance Criteria**:
- AC-03a: When panning reaches the top edge of diagram content, continued upward scroll overflows to scroll the document upward.
- AC-03b: When panning reaches the bottom edge of diagram content, continued downward scroll overflows to scroll the document downward.
- AC-03c: When panning reaches the left edge of diagram content, continued leftward scroll overflows to scroll the document leftward (if the document scrolls horizontally).
- AC-03d: When panning reaches the right edge of diagram content, continued rightward scroll overflows to scroll the document rightward (if the document scrolls horizontally).
- AC-03e: The transition from diagram panning to document scrolling is seamless -- no jerk, snap, or pause at the boundary.
- AC-03f: If the diagram content is smaller than its visible frame (no scrollable content), all scroll gestures pass through to the document immediately.

### FR-04: Pinch-to-Zoom Always Active
**Priority**: Must Have
**Actor**: Diagram Explorer
**Requirement**: Pinch-to-zoom (MagnifyGesture) must always respond when the cursor is hovering over a Mermaid diagram, without any activation step or intent detection.
**Rationale**: Zoom intent is unambiguous -- a pinch gesture on a diagram always means "zoom this diagram." There is no competing interpretation.
**Acceptance Criteria**:
- AC-04a: Pinch-to-zoom works immediately when the cursor is over a Mermaid diagram.
- AC-04b: Zoom range remains clamped to 0.5x - 4.0x.
- AC-04c: Zooming does not interfere with document scrolling before, during, or after the zoom gesture.
- AC-04d: Zooming in on a diagram that makes its content larger than the visible frame enables panning (the now-larger content becomes pannable).
- AC-04e: Zooming out on a diagram that makes its content smaller than the visible frame causes subsequent scroll gestures to pass through to the document (per FR-03f).

### FR-05: No Visible Activation State
**Priority**: Must Have
**Actor**: Document Reader / Diagram Explorer
**Requirement**: There must be no visible indicator of an "activated" or "focused" state on a Mermaid diagram. The diagram looks the same whether the user is scrolling past it or panning within it.
**Rationale**: The current implementation shows a colored border when a diagram is activated. The new momentum-based system has no discrete activation state, so there is no state to indicate. The interaction is invisible.
**Acceptance Criteria**:
- AC-05a: No border, outline, glow, or other visual indicator appears on a diagram during panning.
- AC-05b: No border, outline, glow, or other visual indicator appears on a diagram during zooming.
- AC-05c: The diagram's visual presentation is identical at all times, regardless of interaction state.

### FR-06: Document Scroll Continuity
**Priority**: Must Have
**Actor**: Document Reader
**Requirement**: A user scrolling through a Markdown document containing one or more Mermaid diagrams must experience completely uninterrupted scrolling. Diagrams are transparent to document-level scroll when the user's intent is document navigation.
**Rationale**: This is the primary failure mode of the current implementation. Scroll continuity is non-negotiable.
**Acceptance Criteria**:
- AC-06a: Scrolling at any speed through a document with diagrams never causes a scroll trap or pause at a diagram boundary.
- AC-06b: Scrolling through a document with multiple consecutive diagrams never causes scroll interruption.
- AC-06c: Momentum scrolling (post-flick coasting) carries through diagrams without interruption.
- AC-06d: A user who scrolls up and then immediately scrolls down over the same diagram experiences no capture in either direction.

### FR-07: Multiple Diagrams in Document
**Priority**: Must Have
**Actor**: Document Reader / Diagram Explorer
**Requirement**: The gesture system must work correctly when a document contains multiple Mermaid diagrams, including diagrams that are adjacent or near each other.
**Rationale**: Real-world Markdown documents produced by coding agents often contain multiple diagrams in sequence.
**Acceptance Criteria**:
- AC-07a: Each diagram independently tracks its own pan offset and zoom level.
- AC-07b: Scrolling between two adjacent diagrams does not cause either diagram to capture the scroll.
- AC-07c: The user can pan within one diagram, scroll to a different diagram, and pan within that second diagram independently.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- Gesture response latency must be imperceptible. Intent detection must not introduce any delay visible to the user between gesture input and either diagram panning or document scrolling.
- The momentum detection logic must execute within a single frame (~16ms at 60fps, ~8ms at 120fps ProMotion) to avoid dropped frames.

### 6.2 Security Requirements

- No additional security requirements beyond existing application scope.

### 6.3 Usability Requirements

- The interaction must feel identical to how embedded scroll views behave in the best-in-class macOS applications (e.g., Maps embedded in a scrolling page, or code editors with horizontally scrollable regions).
- A user who has never been told how the interaction works should be able to use it correctly on first encounter.
- The interaction must work identically on macOS trackpads. Magic Mouse compatibility is desirable but not blocking.

### 6.4 Compliance Requirements

- Must respect macOS system preferences for scroll direction (natural vs. inverted).
- Must respect macOS system preferences for trackpad scroll speed.

## 7. User Stories

### STORY-01: Uninterrupted Document Reading
**As a** developer reading a long Markdown document with embedded diagrams,
**I want** to scroll through the entire document without my scroll being captured by any diagram,
**So that** I can read the document fluidly from top to bottom without interruption.

**Acceptance**:
- GIVEN the user is scrolling through a document at any speed
- WHEN the scroll passes over one or more Mermaid diagrams
- THEN the document scroll continues uninterrupted through all diagram boundaries

### STORY-02: Spontaneous Diagram Exploration
**As a** developer who notices an interesting Mermaid diagram while reading,
**I want** to immediately start panning the diagram with a two-finger scroll without any click or activation step,
**So that** I can explore the diagram's details with zero friction.

**Acceptance**:
- GIVEN the user has stopped scrolling and their cursor rests over a Mermaid diagram
- WHEN they initiate a fresh two-finger scroll gesture
- THEN the diagram content pans in response to the gesture

### STORY-03: Returning to Document After Diagram Exploration
**As a** developer who has finished exploring a diagram,
**I want** to seamlessly resume scrolling the document without pressing Escape or clicking outside the diagram,
**So that** the transition from diagram interaction back to document reading is invisible.

**Acceptance**:
- GIVEN the user is panning within a diagram
- WHEN they pan past the edge of the diagram content
- THEN the scroll overflows to the parent document scroll without any manual mode switch

### STORY-04: Quick Zoom on a Diagram
**As a** developer who wants to see fine details in a Mermaid diagram,
**I want** to pinch-to-zoom on the diagram at any time without clicking first,
**So that** zooming feels as natural as zooming on a photo in Preview.

**Acceptance**:
- GIVEN the user's cursor is over a Mermaid diagram
- WHEN they perform a pinch-to-zoom gesture
- THEN the diagram zooms in or out immediately, clamped to 0.5x-4.0x

### STORY-05: Momentum Scroll Through Diagrams
**As a** developer who flick-scrolls quickly through a document,
**I want** the momentum to carry me straight through any diagrams in the path,
**So that** flick-scrolling works the same as in every other macOS application.

**Acceptance**:
- GIVEN the user has performed a flick scroll and the document is coasting on momentum
- WHEN the viewport passes over one or more Mermaid diagrams
- THEN the momentum scroll continues without deceleration, capture, or interruption

## 8. Business Rules

| ID | Rule |
|----|------|
| BR-01 | A scroll gesture that began outside a diagram boundary is always a document scroll, regardless of where the cursor is when the gesture ends. |
| BR-02 | A scroll gesture that began with the cursor stationary over a diagram is always a diagram pan, until the diagram content edge is reached. |
| BR-03 | Momentum-phase scroll events (coasting after finger lift) are always document scroll, never diagram pan. |
| BR-04 | Pinch-to-zoom is always a diagram interaction, never a document interaction. |
| BR-05 | When diagram content is smaller than the diagram's visible frame, the diagram has no scrollable content, and all scroll gestures pass through to the document. |
| BR-06 | Each diagram maintains independent pan offset and zoom state. Interacting with one diagram has no effect on any other diagram. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| MermaidBlockView | Internal | The existing view that renders Mermaid diagrams; this feature replaces its gesture handling |
| Parent document ScrollView | Internal | The document-level scroll container that diagram gesture handling must not interfere with |
| macOS trackpad event system | Platform | The underlying event system that provides scroll phase and momentum information |
| Mermaid Rendering PRD (Phase 4) | Internal | This feature fulfills and refines the "Scroll isolation" and "Gesture Support" requirements from Phase 4 of the parent PRD |

### Constraints

| Constraint | Description |
|------------|-------------|
| No WKWebView | Project-wide architectural constraint; all gesture handling must be native |
| macOS 14.0+ | Minimum deployment target; gesture APIs must be available on macOS 14 |
| Swift 6 strict concurrency | Any shared gesture state must respect actor isolation or Sendable constraints |
| Charter design philosophy | "Ship when magical" -- this feature must not ship until the interaction feels invisible and perfect |

## 10. Clarifications Log

| Question | Answer | Source |
|----------|--------|--------|
| What signal distinguishes "intent to pan diagram" from "scrolling through document"? | Momentum-based detection. Only fresh scroll gestures (started while hovering) control the diagram. Momentum-carry scrolls pass through. | User clarification |
| What happens when panning reaches the edge of diagram content? | Scroll overflows to the parent document scroll (break-out behavior), matching embedded scroll views in most macOS apps. | User clarification |
| Does pinch-to-zoom need intent detection? | No. Pinch-to-zoom always works when hovering over a diagram. Zoom intent is unambiguous. | User clarification |
| What is the quality bar for shipping? | "Ship when magical." Only ship when the interaction feels invisible and perfect. Matches the charter's "no element too small to get right" ethos. | User clarification |
| Does this need to work with Magic Mouse? | Desirable but not blocking for v1. Trackpad is the primary input device. | Inferred from target user profile (terminal-centric developers on MacBooks) |
| Should click-to-activate remain as a fallback? | No. The momentum-based system fully replaces click-to-activate. There is no activation state. | Inferred from "no visible activation state" requirement and the goal of invisible interaction |
