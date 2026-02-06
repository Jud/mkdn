# Requirements Specification: Mermaid Diagram Rendering

**Feature ID**: mermaid-rendering
**Parent PRD**: [Mermaid Rendering](../../prds/mermaid-rendering.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

mkdn renders Mermaid diagram code blocks found in Markdown documents as native SwiftUI images entirely in-process, providing developers with beautiful, zoomable, scrollable diagram previews without leaving their Markdown viewer. The rendering pipeline converts Mermaid syntax through JavaScriptCore evaluation to SVG and then to native images, with caching for performance and graceful error handling for reliability.

## 2. Business Context

### 2.1 Problem Statement

Developers working with LLMs and coding agents frequently produce Markdown documents containing Mermaid diagrams -- architecture docs, sequence diagrams, state machines, ER models. Existing Markdown viewers either do not render Mermaid at all (showing raw code blocks), require a web browser or WKWebView, or produce low-quality non-interactive output. Developers need a native, fast, gesture-friendly way to view these diagrams inline within their Markdown preview.

### 2.2 Business Value

- Completes the Markdown rendering story: mkdn cannot be a daily-driver Markdown viewer if it shows raw text for diagram blocks.
- Differentiator: native gesture support (pinch-to-zoom, panning) on diagrams is rare among Markdown tools.
- Enables the "Diagram Review" workflow identified in the concept map: open file with Mermaid, pinch-to-zoom on diagram.
- Reinforces the project's "no WKWebView" identity by proving complex rendering can be done natively.

### 2.3 Success Metrics

| Metric | Target |
|--------|--------|
| Diagram render success rate | 100% for valid Mermaid syntax across all 5 supported types |
| Perceived render time | Feels near-instant for typical diagrams (under ~500ms perceived) |
| Error recovery rate | 100% -- no app crashes from malformed Mermaid input |
| Document scroll integrity | 0 incidents of scroll hijacking by diagram views |
| Daily-driver adoption | Creator uses mkdn to review Mermaid-containing docs without switching to another tool |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Developer (primary) | Terminal-centric developer who opens Markdown files from CLI, reviews docs containing diagrams produced by LLMs/agents | Direct consumer of rendered Mermaid diagrams |
| Document Author | Developer who writes Markdown with Mermaid blocks and wants to preview them in real-time via side-by-side mode | Needs fast re-render on content changes |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project Creator | Mermaid rendering is a charter-level "Will Do" item and key differentiator; must work flawlessly to support daily-driver use |
| End Users | Need diagrams to render beautifully, respond to native gestures, and never interfere with document reading flow |

## 4. Scope Definition

### 4.1 In Scope

- Native rendering pipeline: Mermaid text to native SwiftUI Image via JavaScriptCore and SVG rasterization
- Five diagram types: flowchart, sequence, state, class, ER (entity-relationship)
- SVG string caching keyed by source hash with bounded cache and eviction policy
- Async rendering with three UI states: loading (spinner), success (rendered image), error (warning + message)
- Pinch-to-zoom gesture on rendered diagrams (0.5x to 4.0x range)
- Two-finger scroll/pan within diagrams, activated only on explicit interaction (not passively)
- Scroll isolation: document-level scrolling must never be captured by diagram views
- Theme-aware diagram containers (background and foreground colors from active theme)
- Graceful degradation: invalid Mermaid input always produces an error state view, never a crash
- Cache clearing capability

### 4.2 Out of Scope

- WASM-based rendering (investigated and ruled out per PRD)
- WKWebView-based rendering (project-wide constraint)
- Interactive/editable diagrams (click-to-edit nodes, drag-to-rearrange)
- Diagram types beyond the five listed (gantt, pie, journey, gitgraph, mindmap, etc.)
- Exporting rendered diagrams as standalone image files
- Server-side or cloud rendering
- Diagram source editing UI (separate from the general Markdown editor)

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A1 | beautiful-mermaid.js (zero-DOM) works in JavaScriptCore without browser APIs | Must find or create a DOM-free Mermaid renderer |
| A2 | SwiftDraw handles all SVG features in beautiful-mermaid output | Some SVG elements may not render; would need SVG post-processing or fallback |
| A3 | JavaScriptCore string-heavy performance is adequate for this workload | May need to revisit rendering approach if performance is poor |
| A4 | Five diagram types cover the vast majority of developer use cases | Users may request additional diagram types in future iterations |
| A5 | Scroll isolation is achievable with SwiftUI's gesture system | May require AppKit interop or custom NSScrollView subclass |

## 5. Functional Requirements

### FR-MER-001: Mermaid Block Detection
- **Priority**: Must Have
- **User Type**: Developer
- **Requirement**: When a Markdown document contains a fenced code block with the language identifier `mermaid`, the system must recognize it as a Mermaid diagram and route it to the Mermaid rendering pipeline rather than displaying it as a plain code block.
- **Rationale**: This is the entry point for the entire feature; without detection, no diagrams render.
- **Acceptance Criteria**:
  - AC1: A fenced code block tagged with ` ```mermaid ` is identified as a Mermaid block.
  - AC2: The raw Mermaid source text is extracted and passed to the rendering pipeline.
  - AC3: Non-mermaid code blocks are unaffected and continue to render as syntax-highlighted code.

### FR-MER-002: Mermaid-to-SVG Conversion
- **Priority**: Must Have
- **User Type**: Developer
- **Requirement**: The system must convert valid Mermaid diagram source text into an SVG string representation using an in-process JavaScript evaluation engine and the beautiful-mermaid library.
- **Rationale**: SVG is the intermediate format that enables native rasterization without a web view.
- **Acceptance Criteria**:
  - AC1: Valid flowchart Mermaid syntax produces a well-formed SVG string.
  - AC2: Valid sequence diagram syntax produces a well-formed SVG string.
  - AC3: Valid state diagram syntax produces a well-formed SVG string.
  - AC4: Valid class diagram syntax produces a well-formed SVG string.
  - AC5: Valid ER diagram syntax produces a well-formed SVG string.
  - AC6: The JavaScript execution occurs entirely in-process with no network calls or external processes.

### FR-MER-003: SVG-to-Native-Image Rasterization
- **Priority**: Must Have
- **User Type**: Developer
- **Requirement**: The system must convert the SVG string output from Mermaid rendering into a native image suitable for display in SwiftUI.
- **Rationale**: Native images enable standard SwiftUI layout, gestures, and theme integration.
- **Acceptance Criteria**:
  - AC1: A valid SVG string is rasterized into a displayable native image.
  - AC2: The resulting image preserves visual fidelity of the original SVG (lines, text, shapes, colors).
  - AC3: The image is displayed inline within the Markdown document at the position of the original Mermaid code block.

### FR-MER-004: Rendering State UI
- **Priority**: Must Have
- **User Type**: Developer
- **Requirement**: While a Mermaid diagram is being rendered, the system must show a loading indicator. On success, it must show the rendered image. On failure, it must show an error state with a meaningful message.
- **Rationale**: Async rendering requires clear visual feedback so users know the system is working and can diagnose issues with malformed diagrams.
- **Acceptance Criteria**:
  - AC1: A loading spinner is displayed while rendering is in progress.
  - AC2: On successful render, the spinner is replaced by the rendered diagram image.
  - AC3: On render failure, a warning icon and a human-readable error message are displayed.
  - AC4: The error message includes enough context to help the user identify the problem in their Mermaid source.

### FR-MER-005: SVG Cache
- **Priority**: Must Have
- **User Type**: Developer, Document Author
- **Requirement**: The system must cache rendered SVG strings keyed by the hash of the Mermaid source text, so that re-rendering the same diagram (e.g., on document reload or view re-layout) does not require re-executing the JavaScript pipeline.
- **Rationale**: Caching eliminates redundant rendering work, making document scrolling and view transitions feel instant.
- **Acceptance Criteria**:
  - AC1: Rendering the same Mermaid source text a second time returns the cached SVG without re-executing JavaScript.
  - AC2: Changing the Mermaid source text (even by one character) results in a cache miss and a fresh render.
  - AC3: The cache has a bounded size with an eviction policy to prevent unbounded memory growth.
  - AC4: A cache-clearing capability exists that forces all diagrams to re-render on next display.

### FR-MER-006: Pinch-to-Zoom
- **Priority**: Must Have
- **User Type**: Developer
- **Requirement**: Users must be able to pinch-to-zoom on a rendered Mermaid diagram to magnify or reduce it, within a range of 0.5x to 4.0x magnification.
- **Rationale**: Diagrams vary widely in complexity and size; zoom is essential for readability of dense diagrams and for seeing the big picture of large ones.
- **Acceptance Criteria**:
  - AC1: A pinch gesture on a rendered diagram increases or decreases the magnification level.
  - AC2: Magnification is clamped to the range 0.5x (minimum) to 4.0x (maximum).
  - AC3: Zoom level persists while the diagram is displayed (does not reset on re-layout).
  - AC4: The zoom gesture feels smooth and responsive with no visible lag.

### FR-MER-007: Two-Finger Scroll/Pan
- **Priority**: Must Have
- **User Type**: Developer
- **Requirement**: Users must be able to pan/scroll within a rendered Mermaid diagram using two-finger scrolling, in both horizontal and vertical directions, but only when the diagram has explicit focus or activation.
- **Rationale**: Zoomed-in diagrams may be larger than the visible container; panning lets users explore the full diagram. Requiring explicit activation prevents accidental scroll capture.
- **Acceptance Criteria**:
  - AC1: Two-finger scrolling within an activated/focused diagram pans the view horizontally and vertically.
  - AC2: The diagram must be explicitly activated (e.g., clicked) before internal scrolling is enabled.
  - AC3: Panning is bounded to the content area of the diagram (cannot scroll past edges into empty space).

### FR-MER-008: Scroll Isolation
- **Priority**: Must Have
- **User Type**: Developer
- **Requirement**: When a user is scrolling the Markdown document top-to-bottom, their scroll gestures must pass through Mermaid diagram views without being captured. Diagram-internal scrolling must only activate on explicit user interaction with the diagram.
- **Rationale**: This is a first-class UX requirement. Scroll hijacking by embedded diagram views would make the document unreadable and frustrating to navigate. The document scroll must always feel predictable.
- **Acceptance Criteria**:
  - AC1: Scrolling the Markdown document with a two-finger gesture moves the document, not the contents of a Mermaid diagram.
  - AC2: A Mermaid diagram that is partially visible does not trap or redirect scroll momentum.
  - AC3: Only after the user explicitly interacts with a diagram (e.g., clicking it) does the diagram capture scroll input for internal panning.
  - AC4: Clicking outside the diagram or pressing Escape deactivates diagram-internal scrolling and returns scroll control to the document.

### FR-MER-009: Theme-Aware Diagram Containers
- **Priority**: Should Have
- **User Type**: Developer
- **Requirement**: Mermaid diagram containers must use the active theme's secondary background and foreground colors, so diagrams visually integrate with the rest of the Markdown preview.
- **Rationale**: Visual consistency with the Solarized theme is a core value of mkdn's design philosophy.
- **Acceptance Criteria**:
  - AC1: The diagram container background uses the active theme's secondary background color.
  - AC2: Text labels and borders within the container use the active theme's secondary foreground color.
  - AC3: Switching themes updates diagram container colors without requiring a re-render of the diagram image itself.

### FR-MER-010: Graceful Error Handling
- **Priority**: Must Have
- **User Type**: Developer
- **Requirement**: The system must never crash due to malformed Mermaid input, JavaScript errors, or SVG rasterization failures. All errors must be caught and presented as user-visible error states.
- **Rationale**: Markdown files from LLMs and agents may contain incomplete or invalid Mermaid syntax. The app must remain stable and informative.
- **Acceptance Criteria**:
  - AC1: Malformed Mermaid syntax (e.g., missing diagram type, broken arrows) produces an error state view, not a crash.
  - AC2: JavaScript execution errors (e.g., runtime exceptions in beautiful-mermaid.js) produce an error state view with the JS error message.
  - AC3: SVG rasterization failures (e.g., invalid SVG data from JS) produce an error state view.
  - AC4: Empty Mermaid code blocks produce an appropriate error or empty state, not a crash.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Aspect | Expectation |
|--------|-------------|
| Perceived render time | Near-instant for typical diagrams; user should not feel they are waiting |
| Cache hit performance | Retrieving a cached SVG and rasterizing it should add negligible delay to document rendering |
| Scroll performance | Document scrolling must remain smooth (60fps) even with multiple Mermaid diagrams visible |
| Memory release | Image data for diagrams that have scrolled off-screen should be eligible for release |

### 6.2 Security Requirements

| Aspect | Expectation |
|--------|-------------|
| JavaScript sandboxing | All JS execution occurs within an in-process JavaScriptCore context with no network access, file system access, or process spawning capability |
| Input sanitization | Mermaid source text is passed to JS evaluation; the JS context must be isolated so that malicious input cannot escape the sandbox |

### 6.3 Usability Requirements

| Aspect | Expectation |
|--------|-------------|
| Discoverability | Diagrams render automatically; no user action needed to trigger rendering |
| Error clarity | Error messages must be understandable to a developer familiar with Mermaid syntax |
| Gesture naturalness | Pinch-to-zoom and pan must feel like native macOS interactions (matching Maps, Preview, etc.) |
| Scroll predictability | Document scrolling must always behave as expected; no scroll traps or unexpected behavior |
| Visual integration | Diagrams must feel like part of the document, not foreign embedded widgets |

### 6.4 Compliance Requirements

No regulatory or compliance requirements apply to this feature.

## 7. User Stories

### STORY-MER-001: View Mermaid Diagram in Preview
- **As a** developer reviewing a Markdown document
- **I want** Mermaid code blocks to automatically render as visual diagrams
- **So that** I can understand the documented architecture, flows, and relationships without copy-pasting into a separate tool

**Acceptance Scenarios**:
- GIVEN a Markdown file containing a ` ```mermaid ` flowchart code block
  WHEN I open the file in mkdn
  THEN the flowchart is rendered as a visual diagram inline in the preview

- GIVEN a Markdown file containing multiple Mermaid code blocks of different types
  WHEN I open the file in mkdn
  THEN each diagram is rendered correctly at its respective position in the document

### STORY-MER-002: Zoom Into a Complex Diagram
- **As a** developer reviewing a complex class or ER diagram
- **I want** to pinch-to-zoom on the diagram to magnify specific areas
- **So that** I can read labels and relationships that are too small at the default scale

**Acceptance Scenarios**:
- GIVEN a rendered Mermaid ER diagram with many entities
  WHEN I perform a pinch-to-zoom gesture on the diagram
  THEN the diagram magnifies smoothly up to 4.0x

- GIVEN a diagram zoomed to 4.0x
  WHEN I attempt to zoom further
  THEN the zoom level stays clamped at 4.0x

### STORY-MER-003: Pan a Zoomed Diagram
- **As a** developer who has zoomed into a large diagram
- **I want** to pan around the diagram with two-finger scrolling
- **So that** I can explore different parts of the diagram without zooming out

**Acceptance Scenarios**:
- GIVEN a diagram zoomed to 2.0x that is larger than its container
  WHEN I click the diagram to activate it and then two-finger scroll
  THEN the diagram pans to show the scrolled area

- GIVEN an activated diagram
  WHEN I click outside the diagram
  THEN diagram panning deactivates and document scrolling resumes

### STORY-MER-004: Scroll Past Diagrams Without Interruption
- **As a** developer reading a long Markdown document with embedded diagrams
- **I want** my document scroll to pass through diagram views without getting stuck
- **So that** I can read the document fluidly from top to bottom

**Acceptance Scenarios**:
- GIVEN a Markdown document with three Mermaid diagrams interspersed with text
  WHEN I scroll continuously from top to bottom
  THEN the scroll moves smoothly through the entire document, passing over diagrams without stopping

- GIVEN a Mermaid diagram partially visible on screen
  WHEN I continue scrolling downward
  THEN the scroll continues past the diagram without any hitch or capture

### STORY-MER-005: See Error for Invalid Mermaid
- **As a** developer previewing a document with broken Mermaid syntax
- **I want** to see a clear error message where the diagram would appear
- **So that** I know the diagram failed and can fix the Mermaid source

**Acceptance Scenarios**:
- GIVEN a Mermaid code block with invalid syntax (e.g., `graph TD; A --> ;`)
  WHEN the file is rendered in preview
  THEN an error state is shown at the diagram position with a meaningful error message

- GIVEN a completely empty Mermaid code block
  WHEN the file is rendered in preview
  THEN an appropriate error or empty state is shown, and the app does not crash

### STORY-MER-006: Fast Re-Render on Document Reload
- **As a** developer who reloads a Markdown file after external changes
- **I want** previously rendered diagrams to appear instantly from cache
- **So that** reloading the document feels fast even with many diagrams

**Acceptance Scenarios**:
- GIVEN a document with 5 Mermaid diagrams that have been rendered once
  WHEN I reload the document without changing any Mermaid source
  THEN all 5 diagrams appear instantly from cache without showing loading spinners

- GIVEN a document where one Mermaid diagram has been edited externally
  WHEN I reload the document
  THEN the changed diagram re-renders (showing a spinner briefly) while the unchanged diagrams load from cache

## 8. Business Rules

| ID | Rule |
|----|------|
| BR-001 | Only the five supported diagram types (flowchart, sequence, state, class, ER) are rendered. Unsupported types should show a clear "unsupported diagram type" message, not a cryptic JS error. |
| BR-002 | The rendering pipeline must never use WKWebView or any web view component (project-wide constraint). |
| BR-003 | Diagram rendering must not block the main thread or degrade document scrolling performance. |
| BR-004 | Cache size must be bounded to prevent unbounded memory growth in documents with many diagrams. |
| BR-005 | Scroll isolation takes precedence over diagram interactivity -- if there is any conflict, document scroll wins. |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| apple/swift-markdown | Internal | Upstream Markdown parser that identifies Mermaid code blocks |
| JXKit | External (SPM) | Swift-friendly JavaScriptCore wrapper for in-process JS evaluation |
| SwiftDraw | External (SPM) | SVG parsing and rasterization to NSImage |
| beautiful-mermaid.js | Bundled Resource | Zero-DOM Mermaid rendering library loaded from app bundle |
| AppState.theme | Internal | Theme colors for diagram container styling |
| Core Markdown Rendering feature | Internal | The Markdown rendering pipeline must be able to delegate Mermaid blocks to this feature |

### Constraints

| Constraint | Description |
|------------|-------------|
| No WKWebView | Project-wide architectural constraint; all rendering must be native |
| No WASM | Investigated and ruled out; string-heavy workload favors JavaScriptCore |
| macOS 14.0+ | Minimum deployment target |
| Swift 6 strict concurrency | All shared state must use actors or other concurrency-safe patterns |
| beautiful-mermaid.js availability | The JS bundle must be bundled in app resources; no runtime download |

## 10. Clarifications Log

| Item | Question | Resolution | Source |
|------|----------|------------|--------|
| CL-001 | What cache eviction strategy should be used? | Left as implementation decision; requirement is bounded cache with eviction. PRD lists LRU vs. count-limited as open question. | PRD Open Questions |
| CL-002 | Exact scroll isolation UX: click-to-focus vs. hover-to-activate vs. modifier-key? | Defaulted to click-to-focus as most conservative and predictable option. | PRD Open Questions, conservative default |
| CL-003 | Should JXContext be reused across renders or created fresh each time? | Left as implementation/performance decision. Requirement is near-instant perceived render time. PRD Phase 5 addresses this. | PRD Phase 5 |
| CL-004 | What happens for unsupported Mermaid diagram types (gantt, pie, etc.)? | Should show a clear "unsupported diagram type" message. Added as BR-001. | Inferred from scope + usability requirements |
| CL-005 | Should zoom level persist per-diagram across document reloads? | Not required for initial version. Zoom resets on reload. | Conservative default |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | mermaid-rendering.md | Exact filename match with feature ID |
| Charter association | charter.md | Standard project charter, referenced by PRD |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| No explicit requirements text provided (REQUIREMENTS param empty) | Derived all requirements from PRD mermaid-rendering.md, charter.md, architecture.md, and concept_map.md | PRD + KB |
| Cache eviction strategy unspecified (PRD open question) | Specified "bounded cache with eviction" as the requirement; left strategy choice to implementation | PRD Open Questions |
| Scroll isolation activation mechanism (PRD open question) | Defaulted to click-to-focus as most conservative approach that prevents accidental scroll capture | PRD Open Questions, conservative default |
| JXContext reuse vs. fresh-per-render (PRD open question) | Left as implementation decision; requirement expressed as performance expectation ("near-instant") | PRD Phase 5 |
| Unsupported diagram type behavior not explicitly stated | Inferred: show clear "unsupported type" message rather than cryptic error | Usability requirements + scope definition |
| Zoom persistence across document reloads | Not required; zoom resets on reload (conservative default for MVP) | Conservative default |
| Diagram deactivation mechanism | Click-outside or Escape key returns scroll control to document | Inferred from scroll isolation requirement + macOS conventions |
