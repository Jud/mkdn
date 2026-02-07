# Requirements Specification: Mermaid Diagram Rendering Re-Architecture

**Feature ID**: mermaid-rearchitect
**Parent PRD**: [Mermaid Re-Architect](../../prds/mermaid-rearchitect.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-07

## 1. Feature Overview

Replace the existing Mermaid diagram rendering pipeline (JavaScriptCore + beautiful-mermaid.js + SwiftDraw SVG rasterization + custom gesture handling) with a WKWebView-per-diagram approach that uses standard Mermaid.js in its native web rendering context. This eliminates the fragile multi-stage rendering chain while preserving theme-aware, gesture-enabled diagram viewing within the otherwise fully native SwiftUI application.

## 2. Business Context

### 2.1 Problem Statement

The current Mermaid rendering pipeline chains together four distinct technologies (JavaScriptCore, beautiful-mermaid.js, SwiftDraw, custom SwiftUI gesture systems) creating a fragile pipeline where failures at any stage produce degraded or broken output. The beautiful-mermaid.js library is a non-standard Mermaid implementation that may not faithfully render all diagram constructs. The custom gesture system for scroll isolation, pinch-to-zoom, and panning requires complex heuristics that have proven difficult to get right without interfering with document scrolling. Developers viewing Markdown artifacts with Mermaid diagrams need diagrams that render correctly, reliably, and with natural interaction behavior.

### 2.2 Business Value

- **Reliability**: Standard Mermaid.js in WKWebView is the canonical rendering environment, eliminating the risk of rendering discrepancies from the JSC + beautiful-mermaid + SwiftDraw chain.
- **Simplicity**: Replaces seven source files and complex custom gesture code with a single WKWebView wrapper, reducing maintenance burden and defect surface area.
- **Interaction quality**: WKWebView provides native pinch-to-zoom and panning without custom gesture classifiers or scroll phase monitors.
- **Developer experience**: Diagrams in Markdown artifacts (produced by LLMs and coding agents) render faithfully and behave naturally, supporting the daily-driver use case defined in the project charter.

### 2.3 Success Metrics

- All five supported diagram types (flowchart, sequence, state, class, ER) render correctly in both Solarized Dark and Solarized Light themes.
- Document scrolling is never captured or interrupted by unfocused diagram views.
- Focused diagrams support pinch-to-zoom and two-finger pan without custom gesture code.
- The app builds and runs without SwiftDraw, JXKit, or beautiful-mermaid.js dependencies.
- Typical diagrams render within a timeframe that feels responsive to the user (no visible stall).

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Developer (primary) | Terminal-centric developer using LLMs and coding agents, viewing Markdown artifacts containing Mermaid diagrams | Direct consumer of diagram rendering; needs correct rendering, natural interaction, and theme consistency |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator/maintainer | Daily-driver quality for viewing Mermaid diagrams in agent-produced Markdown; reduced maintenance burden from simpler pipeline |

## 4. Scope Definition

### 4.1 In Scope

- Removal of the entire existing Mermaid rendering pipeline (MermaidRenderer actor, SVGSanitizer, MermaidCache, MermaidImageStore, ScrollPhaseMonitor, GestureIntentClassifier, DiagramPanState) and their corresponding tests
- Removal of SwiftDraw and JXKit SPM dependencies
- Removal of beautiful-mermaid.js bundled resource
- New WKWebView-per-diagram rendering approach using standard Mermaid.js
- Theme-aware diagram rendering matching Solarized Dark/Light
- Scroll pass-through for unfocused diagrams
- Click-to-focus interaction model with visual indicator
- Escape/click-outside to unfocus
- Loading and error state UI for diagram rendering
- Auto-sizing of diagram views to fit rendered content
- Re-rendering on theme change
- Diagram types: flowchart, sequence, state, class, ER

### 4.2 Out of Scope

- Interactive or editable diagrams (click-to-edit nodes, drag-to-rearrange)
- Diagram types beyond the five listed (gantt, pie, journey, gitgraph, mindmap, etc.)
- Exporting rendered diagrams as standalone image files
- Server-side or cloud rendering
- Using WKWebView for any purpose other than Mermaid diagram rendering
- Complex gesture classification systems or scroll-trapping prevention heuristics
- WKWebView pooling or reuse optimization (may be addressed in a future feature)

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A1 | Standard Mermaid.js renders correctly in WKWebView on macOS 14+ | Extremely low risk; WKWebView is Mermaid's native target environment |
| A2 | WKWebView scroll events can be passed through to the parent SwiftUI scroll view when diagrams are unfocused | May need NSEvent override or hitTest customization; fallback is disabling WKWebView interaction entirely when unfocused |
| A3 | Memory overhead of multiple WKWebViews is acceptable for typical documents with 1-5 diagrams | For diagram-heavy documents, lazy initialization and off-screen teardown may be needed later |
| A4 | SwiftDraw and JXKit are used exclusively for Mermaid rendering and can be fully removed from Package.swift | If used elsewhere, those dependencies must be retained |
| A5 | The five supported diagram types cover the majority of developer use cases for Mermaid in Markdown | Standard Mermaid.js supports all types natively, so adding more later is trivial |
| A6 | Mermaid.js can be bundled locally as a resource, eliminating need for network access | Bundled approach works offline and avoids CDN dependency |

## 5. Functional Requirements

### FR-001: Teardown of Existing Mermaid Pipeline
- **Priority**: Must Have
- **User Type**: Maintainer
- **Requirement**: All existing Mermaid rendering and gesture management code is removed, along with the SwiftDraw and JXKit dependencies and the beautiful-mermaid.js resource.
- **Rationale**: A clean slate prevents confusion from dead code and eliminates unused dependencies, reducing build complexity and binary size.
- **Acceptance Criteria**:
  - AC-001.1: The following source files are deleted: MermaidRenderer.swift, SVGSanitizer.swift, MermaidCache.swift, MermaidImageStore.swift, ScrollPhaseMonitor.swift, GestureIntentClassifier.swift, DiagramPanState.swift
  - AC-001.2: All corresponding test files are deleted
  - AC-001.3: SwiftDraw and JXKit are removed from Package.swift
  - AC-001.4: The beautiful-mermaid.js (mermaid.min.js) resource is deleted and removed from Package.swift
  - AC-001.5: The app builds successfully after removal with Mermaid blocks showing a placeholder or fallback view
  - AC-001.6: No dead imports or references to removed code remain in the codebase

### FR-002: WKWebView-Per-Diagram Rendering
- **Priority**: Must Have
- **User Type**: Developer (primary)
- **Requirement**: Each Mermaid code block in a rendered Markdown document is displayed using its own WKWebView instance that loads an HTML template containing standard Mermaid.js and the diagram source text.
- **Rationale**: Standard Mermaid.js running in WKWebView is the canonical rendering approach, providing correct and complete diagram output without a fragile multi-stage pipeline.
- **Acceptance Criteria**:
  - AC-002.1: Each Mermaid code block detected by the Markdown parser results in a separate WKWebView instance
  - AC-002.2: The WKWebView loads a self-contained HTML template that includes standard Mermaid.js and the diagram source
  - AC-002.3: All five diagram types (flowchart, sequence, state, class, ER) render correctly
  - AC-002.4: WKWebView is wrapped in an NSViewRepresentable for integration with SwiftUI
  - AC-002.5: WKWebView is created and used on the main actor, conforming to Swift 6 concurrency requirements

### FR-003: Theme-Aware Diagram Rendering
- **Priority**: Must Have
- **User Type**: Developer (primary)
- **Requirement**: Diagrams render with colors matching the current application theme (Solarized Dark or Solarized Light), including background, text/label, line/edge, and node fill colors.
- **Rationale**: Terminal-consistent theming is a core differentiator of mkdn; diagrams must visually integrate with the rest of the rendered Markdown document.
- **Acceptance Criteria**:
  - AC-003.1: The HTML template accepts theme colors as CSS variables or Mermaid.js themeVariables configuration derived from the current ThemeColors
  - AC-003.2: Diagrams rendered in Solarized Dark use dark-theme-appropriate colors
  - AC-003.3: Diagrams rendered in Solarized Light use light-theme-appropriate colors
  - AC-003.4: The WKWebView background is transparent or matches the theme background, with no visible white flash or color mismatch

### FR-004: Diagram Re-Rendering on Theme Change
- **Priority**: Must Have
- **User Type**: Developer (primary)
- **Requirement**: When the user switches between Solarized Dark and Solarized Light, all visible Mermaid diagrams re-render with the new theme colors.
- **Rationale**: Users switch themes during use; stale-themed diagrams would visually clash with the rest of the document.
- **Acceptance Criteria**:
  - AC-004.1: After a theme switch, all visible diagrams display colors matching the new theme
  - AC-004.2: Re-rendering occurs without requiring the user to scroll away and back or reload the document

### FR-005: Scroll Pass-Through for Unfocused Diagrams
- **Priority**: Must Have
- **User Type**: Developer (primary)
- **Requirement**: By default (unfocused state), scroll wheel events on a diagram pass through to the parent document scroll view. The WKWebView does not capture or consume scroll events when unfocused.
- **Rationale**: Scroll trapping by diagrams was a critical UX problem in the previous implementation; developers scrolling through a Markdown document must never have their scroll hijacked by a diagram they are passing over.
- **Acceptance Criteria**:
  - AC-005.1: Scrolling the document with the trackpad or mouse wheel passes smoothly through unfocused diagram views without interruption
  - AC-005.2: No custom scroll-phase monitoring or gesture classification heuristics are required

### FR-006: Click-to-Focus Interaction Model
- **Priority**: Must Have
- **User Type**: Developer (primary)
- **Requirement**: Clicking a diagram focuses it, enabling pinch-to-zoom and two-finger pan within the WKWebView. A subtle visual indicator (thin accent-colored border or slight glow) communicates the focus state. Pressing Escape or clicking outside the diagram unfocuses it and returns scroll control to the document.
- **Rationale**: Developers need to inspect diagram details via zoom and pan, but this interaction must be explicitly activated to avoid interfering with document navigation.
- **Acceptance Criteria**:
  - AC-006.1: Clicking a diagram transitions it to focused state
  - AC-006.2: A visual indicator (border or glow) is visible when a diagram is focused
  - AC-006.3: In focused state, pinch-to-zoom works within the diagram
  - AC-006.4: In focused state, two-finger pan works within the diagram
  - AC-006.5: Pressing Escape unfocuses the diagram and returns scroll control to the document
  - AC-006.6: Clicking outside a focused diagram unfocuses it

### FR-007: Async Rendering with Loading and Error States
- **Priority**: Must Have
- **User Type**: Developer (primary)
- **Requirement**: While WKWebView initializes and Mermaid.js renders the diagram, a loading state is displayed. If rendering fails (Mermaid.js parse error, WKWebView failure), an error state with a meaningful message is displayed. The app never crashes due to a diagram rendering failure.
- **Rationale**: Async rendering is inherent to the WKWebView approach; users need visual feedback during rendering and graceful handling of malformed diagram code.
- **Acceptance Criteria**:
  - AC-007.1: A loading indicator (spinner) is displayed while a diagram is rendering
  - AC-007.2: On render failure, a warning icon and descriptive error message are displayed in place of the diagram
  - AC-007.3: Mermaid.js parse errors are caught and surfaced in the error state view
  - AC-007.4: A rendering failure in one diagram does not affect rendering of other diagrams or the rest of the document
  - AC-007.5: No diagram rendering scenario causes the app to crash

### FR-008: Auto-Sizing of Diagram Views
- **Priority**: Must Have
- **User Type**: Developer (primary)
- **Requirement**: Each WKWebView sizes itself to fit the rendered diagram's natural dimensions (as reported by Mermaid.js via a JS-to-Swift message handler), up to a sensible maximum height. Diagrams are not confined to a fixed-size box.
- **Rationale**: Diagrams vary greatly in size; a fixed height either clips large diagrams or wastes space for small ones. Auto-sizing provides the best reading experience.
- **Acceptance Criteria**:
  - AC-008.1: The rendered diagram's natural size is reported from JavaScript to Swift via WKScriptMessageHandler
  - AC-008.2: The WKWebView hosting view sizes itself to match the reported natural dimensions
  - AC-008.3: A maximum height is enforced to prevent extremely tall diagrams from dominating the document
  - AC-008.4: Diagrams shorter than the maximum display at their natural height without extra whitespace

### FR-009: HTML Template for Mermaid Rendering
- **Priority**: Must Have
- **User Type**: Developer (primary)
- **Requirement**: A self-contained HTML template is used that loads Mermaid.js (bundled locally), receives diagram source text, applies theme colors, renders the diagram, and reports the rendered size back to Swift.
- **Rationale**: The HTML template is the core rendering artifact; it must be self-contained and reliable, working offline without network access.
- **Acceptance Criteria**:
  - AC-009.1: Mermaid.js is bundled as a local resource within the app
  - AC-009.2: The HTML template renders diagrams without requiring network access
  - AC-009.3: The template accepts theme configuration (colors) at render time
  - AC-009.4: The template reports the rendered diagram's dimensions to Swift via message handler
  - AC-009.5: The template background is transparent or theme-matching

### FR-010: Dependency Cleanup in Package.swift
- **Priority**: Must Have
- **User Type**: Maintainer
- **Requirement**: SwiftDraw and JXKit SPM dependencies are removed from Package.swift. The beautiful-mermaid.js resource copy rule is removed. The Mermaid.js standard library is added as a bundled resource. WebKit framework usage is introduced.
- **Rationale**: Unused dependencies increase build time, binary size, and maintenance burden. The dependency graph must reflect the actual implementation.
- **Acceptance Criteria**:
  - AC-010.1: SwiftDraw is removed from Package.swift dependencies and targets
  - AC-010.2: JXKit is removed from Package.swift dependencies and targets
  - AC-010.3: The `.copy("Resources/mermaid.min.js")` rule for beautiful-mermaid is removed
  - AC-010.4: Standard Mermaid.js is added as a bundled resource
  - AC-010.5: The project builds and all non-Mermaid tests pass after dependency changes

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- **NFR-001**: Diagram rendering should feel responsive for typical diagrams (fewer than 50 nodes). Users should see the rendered diagram appear without a perceptible stall beyond the loading indicator.
- **NFR-002**: For documents with many diagrams, lazy initialization of WKWebView instances (creating them only when they scroll into or near the viewport) is desirable to avoid upfront overhead.
- **NFR-003**: Memory overhead from multiple WKWebView instances should be acceptable for typical documents with 1-5 diagrams. For documents with significantly more diagrams, off-screen WKWebView teardown and re-creation is a stretch goal.

### 6.2 Security Requirements

- **NFR-004**: The WKWebView must load only local resources (bundled Mermaid.js and the HTML template). No external network requests should be made from the diagram rendering context.
- **NFR-005**: The WKWebView should have JavaScript enabled only to the extent required for Mermaid.js rendering. No navigation to external URLs should be permitted.

### 6.3 Usability Requirements

- **NFR-006**: The interaction model (unfocused scroll-through, click-to-focus, Escape to unfocus) must be immediately intuitive without documentation or onboarding.
- **NFR-007**: The visual focus indicator must be subtle enough not to distract during reading but visible enough to confirm the focused state.
- **NFR-008**: Loading and error states must be visually consistent with the rest of the application's loading/error patterns (ProgressView spinner, warning icon + message).

### 6.4 Compliance Requirements

- **NFR-009**: The implementation must be compatible with macOS 14.0+ and Swift 6 strict concurrency. `@preconcurrency import WebKit` may be used if needed for Sendable conformance.
- **NFR-010**: WKWebView must be used exclusively for Mermaid diagram rendering. No other part of the application may use WKWebView. This constraint must be clearly documented.

## 7. User Stories

### STORY-001: View Mermaid Diagram in Document
- **As a** developer viewing a Markdown file containing Mermaid diagrams
- **I want** the diagrams to render correctly and match my current theme
- **So that** I can read and understand the diagrams without switching to another tool

**Acceptance Tests**:
- GIVEN a Markdown file with a flowchart Mermaid block WHEN opened in mkdn THEN the flowchart renders correctly with theme-appropriate colors
- GIVEN a Markdown file with multiple diagram types WHEN opened in mkdn THEN each diagram renders correctly at its natural size
- GIVEN the app is in Solarized Dark theme WHEN a diagram renders THEN its colors match the dark palette

### STORY-002: Scroll Past Diagrams Without Interruption
- **As a** developer scrolling through a long Markdown document
- **I want** my scroll to pass smoothly through diagram views
- **So that** I can navigate the document without my scroll being captured by embedded diagrams

**Acceptance Tests**:
- GIVEN a document with diagrams interspersed in text WHEN scrolling with the trackpad THEN the scroll passes through all diagrams without stopping or being captured
- GIVEN an unfocused diagram WHEN the mouse cursor is over the diagram and the user scrolls THEN the document continues to scroll normally

### STORY-003: Interact with a Diagram
- **As a** developer who wants to inspect a diagram in detail
- **I want** to click a diagram to zoom and pan within it
- **So that** I can read small labels or explore large diagrams

**Acceptance Tests**:
- GIVEN an unfocused diagram WHEN the user clicks on it THEN a visual focus indicator appears and zoom/pan gestures work within the diagram
- GIVEN a focused diagram WHEN the user presses Escape THEN the diagram unfocuses and scroll control returns to the document
- GIVEN a focused diagram WHEN the user clicks outside of it THEN the diagram unfocuses

### STORY-004: View Rendering Feedback
- **As a** developer opening a document with Mermaid diagrams
- **I want** to see loading indicators while diagrams render and clear error messages if they fail
- **So that** I know the app is working and can diagnose problems with my diagram syntax

**Acceptance Tests**:
- GIVEN a document with diagrams WHEN the document is first opened THEN each diagram area shows a loading spinner until rendering completes
- GIVEN a Mermaid block with invalid syntax WHEN the diagram renders THEN an error state with a descriptive message is shown instead of the diagram
- GIVEN one diagram fails to render WHEN viewing the document THEN all other diagrams and text render normally

### STORY-005: Switch Theme with Active Diagrams
- **As a** developer who switches between Solarized Dark and Light
- **I want** diagrams to update their colors when I change themes
- **So that** diagrams always match the rest of the document's visual appearance

**Acceptance Tests**:
- GIVEN a document with rendered diagrams in Solarized Dark WHEN the user switches to Solarized Light THEN all visible diagrams re-render with light theme colors
- GIVEN a theme switch WHEN diagrams re-render THEN there is no visible flash of the old theme colors

## 8. Business Rules

| ID | Rule |
|----|------|
| BR-001 | WKWebView is used exclusively for Mermaid diagram rendering. No other application component may use WKWebView. |
| BR-002 | The application must function fully offline. Mermaid.js is bundled locally, not loaded from a CDN. |
| BR-003 | A rendering failure in one diagram must never affect other diagrams or the rest of the document. |
| BR-004 | The "No WKWebView" constraint from the original project charter is relaxed for Mermaid diagrams only. This exception must be documented in the charter/CLAUDE.md. |
| BR-005 | All existing Mermaid and gesture code is deleted (clean slate), not incrementally refactored. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Direction | Notes |
|------------|------|-----------|-------|
| WebKit framework | System | Add | WKWebView, WKScriptMessageHandler, WKUserContentController |
| Mermaid.js (standard) | Bundled resource | Add | Standard Mermaid.js library, bundled locally |
| SwiftDraw | SPM | Remove | Only used for Mermaid SVG rasterization |
| JXKit | SPM | Remove | Only used for JSC wrapper in Mermaid rendering |
| beautiful-mermaid.js | Bundled resource | Remove | Replaced by standard Mermaid.js |
| apple/swift-markdown | SPM | Keep | Still identifies Mermaid code blocks in Markdown |
| AppState / AppSettings | Internal | Keep | Theme colors drive the WKWebView HTML template |

### Constraints

- macOS 14.0+ minimum deployment target
- Swift 6 strict concurrency; WKWebView must be created and used on @MainActor
- WKWebView is constrained to Mermaid diagrams only; the rest of the app remains fully native SwiftUI

## 10. Clarifications Log

| # | Question | Resolution | Source |
|---|----------|------------|--------|
| 1 | Should Mermaid.js be bundled locally or loaded from CDN? | Bundle locally for offline support and simplicity | PRD open question; resolved per BR-002 |
| 2 | Should WKWebViews be pooled or reused across diagrams? | Start simple with one WKWebView per diagram; optimize later if needed | PRD open question; conservative default |
| 3 | What is the maximum height for auto-sized diagrams? | Left to implementation to determine based on testing | PRD open question; deferred to design phase |
| 4 | What is the scope of the charter update for the WKWebView exception? | Update charter and CLAUDE.md to note the Mermaid-only WKWebView exception | PRD Phase 5 |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | mermaid-rearchitect.md | Exact filename match with feature ID |
| Mermaid.js delivery method | Bundle locally | PRD recommends bundling; aligns with offline-first (BR-002) and simplicity design philosophy |
| WKWebView pooling/reuse | One per diagram, no pooling | PRD recommends starting simple; conservative default for initial implementation |
| Diagram max height | Deferred to implementation | PRD explicitly leaves to implementation; no business-level constraint needed |
| Lazy initialization of WKWebViews | Desirable but not required for initial implementation | Conservative scope; documented as NFR-002 |
| Off-screen WKWebView teardown | Stretch goal | PRD marks as stretch goal; documented as NFR-003 |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| "Subtle visual indicator" for focus state not precisely defined | Specified as "thin accent-colored border or slight glow" per PRD language; exact styling deferred to design phase | PRD FR-5 |
| "Sensible max" height for auto-sized diagrams not quantified | Left as implementation decision; documented in FR-008 acceptance criteria as requiring a maximum without specifying the value | PRD FR-7 |
| Whether theme re-rendering should use JS re-evaluation or full HTML reload | Either approach is acceptable per PRD FR-10; left to implementation | PRD FR-10 |
| Whether `@preconcurrency import WebKit` is needed | Documented as an option in NFR-009; depends on Swift 6 compiler behavior with WebKit types | PRD NFR-5, KB patterns.md |
| Whether JXKit is used anywhere outside Mermaid rendering | Assumed no, per PRD A4; flagged as assumption A4 with impact noted | PRD Assumptions |
| Exact error message format for Mermaid parse failures | Specified as "warning icon + descriptive error message" consistent with existing app patterns | PRD FR-6, concept_map.md |
