# Requirements Specification: Fix Infinite Scroll Re-render Loop

**Feature ID**: fix-infinite-scroll-rerender
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

The Markdown preview view enters an infinite re-render loop when the user scrolls through content containing Mermaid diagrams. The cycle causes escalating CPU consumption, visible jank, and -- when scrolling quickly -- full application unresponsiveness or a crash. This bug fix must break the re-render cycle so that scrolling through any document, including documents with Mermaid blocks, is smooth and never triggers runaway rendering.

## 2. Business Context

### 2.1 Problem Statement

When a user opens a Markdown file containing one or more Mermaid diagram blocks and scrolls through the preview, the view enters an infinite re-render loop. Mermaid block rendering triggers state updates that cause the parent ScrollView/LazyVStack to re-layout, which causes Mermaid blocks to appear/disappear from the visible region, which re-triggers rendering, creating a self-sustaining cycle. The result ranges from visible flickering and jank to a complete application freeze or crash.

### 2.2 Business Value

mkdn's charter defines success as "personal daily-driver use." A crash-on-scroll bug in the primary read mode (preview) for a common content type (Mermaid diagrams) directly prevents daily-driver adoption. Mermaid diagrams are a first-class feature of the app; they must be scrollable without risk of instability.

### 2.3 Success Metrics

- SM-1: Scrolling through a document containing 5+ Mermaid diagram blocks at any speed produces no visible jank, no runaway CPU, and no crash.
- SM-2: Mermaid diagrams that have already been rendered do not re-execute their rendering pipeline when scrolled in and out of the visible area.
- SM-3: The fix does not degrade initial Mermaid render quality or introduce visible placeholder flicker on first load.

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Markdown Viewer | Developer viewing Markdown artifacts from LLMs/coding agents in preview-only mode | Primary -- this is the mode and workflow where the bug manifests |
| Markdown Editor | Developer using side-by-side edit + preview mode | Secondary -- may also be affected but not yet confirmed |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| End User (developer) | Smooth, crash-free scrolling through all document types |
| Project Owner | App stability sufficient for daily-driver use; Mermaid as a reliable first-class feature |

## 4. Scope Definition

### 4.1 In Scope

- Breaking the infinite re-render cycle triggered by scrolling past Mermaid blocks in preview mode.
- Ensuring Mermaid diagram rendered output is preserved/cached so that scrolling blocks in and out of the visible area does not re-trigger the full rendering pipeline (JavaScriptCore execution, SVG rasterization).
- Ensuring the fix also covers side-by-side editor mode if the same rendering path is shared.
- Verifying that other block types (images, code blocks, tables) inside LazyVStack do not exhibit similar re-render behavior.

### 4.2 Out of Scope

- Improving Mermaid initial render speed or quality (separate concern).
- Adding new Mermaid diagram type support.
- Reworking the overall Markdown parsing pipeline.
- Performance profiling or optimization unrelated to the scroll re-render loop.
- Changes to the editor (text editing) side of the application.

### 4.3 Assumptions

- A-1: The root cause is a state-update cycle where Mermaid block rendering triggers layout changes that cause the LazyVStack to recycle views, which re-triggers rendering.
- A-2: The existing MermaidCache (if utilized) is not effectively preventing re-renders when views are recycled by LazyVStack.
- A-3: The fix can be achieved without architectural changes to the overall rendering pipeline -- it is a targeted fix within the Mermaid block rendering and/or view lifecycle management.

## 5. Functional Requirements

### REQ-001: Break the Scroll Re-render Cycle
- **Priority**: Must Have
- **User Type**: Markdown Viewer
- **Requirement**: When a user scrolls through a document containing Mermaid diagram blocks in preview mode, the scroll action must not trigger re-rendering of Mermaid diagrams that have already completed their initial render.
- **Rationale**: The current behavior creates an infinite loop: scroll causes layout change, layout change triggers Mermaid re-render, Mermaid re-render causes state update, state update causes layout change, repeating indefinitely.
- **Acceptance Criteria**:
  - AC-1a: Scrolling up and down through a document with 5+ Mermaid blocks at normal speed produces no visible re-rendering of already-rendered diagrams.
  - AC-1b: Scrolling rapidly (fast flick gesture) through the same document does not cause the app to become unresponsive.
  - AC-1c: Scrolling rapidly does not cause the app to crash.

### REQ-002: Preserve Rendered Mermaid Output Across View Recycling
- **Priority**: Must Have
- **User Type**: Markdown Viewer
- **Requirement**: When a Mermaid block view is recycled by the lazy layout container (scrolled out of the visible area and back in), the previously rendered diagram image must be restored without re-executing the Mermaid rendering pipeline.
- **Rationale**: LazyVStack destroys and recreates views as they scroll in and out of the visible region. Each recreation currently re-triggers the full async Mermaid pipeline (JSC execution, SVG generation, rasterization), which is the proximate cause of the re-render storm.
- **Acceptance Criteria**:
  - AC-2a: A Mermaid diagram that was fully rendered, then scrolled off-screen, then scrolled back on-screen, appears immediately without a loading indicator.
  - AC-2b: The JavaScriptCore/SVG rendering pipeline is not re-invoked for a Mermaid block whose content has not changed.

### REQ-003: Stable View Identity for Mermaid Blocks
- **Priority**: Must Have
- **User Type**: Markdown Viewer
- **Requirement**: Mermaid block views must maintain a stable identity within the ForEach/LazyVStack so that SwiftUI does not unnecessarily destroy and recreate them during scroll-induced layout passes.
- **Rationale**: If view identity is unstable (e.g., IDs change on re-render), SwiftUI treats each layout pass as containing new views, triggering fresh .task calls and new render cycles.
- **Acceptance Criteria**:
  - AC-3a: The Identifiable conformance for Mermaid blocks produces the same ID for the same Mermaid source code across consecutive render passes.
  - AC-3b: No .task or .onAppear re-fires for a Mermaid block that has not changed content while the user is only scrolling.

### REQ-004: No Degradation of Initial Mermaid Render Experience
- **Priority**: Must Have
- **User Type**: Markdown Viewer
- **Requirement**: The first-time rendering of a Mermaid diagram (when a file is loaded or content changes) must continue to show a loading indicator, then resolve to the rendered diagram, with no regression in visual quality or behavior.
- **Rationale**: The fix must not over-cache or suppress legitimate first renders.
- **Acceptance Criteria**:
  - AC-4a: Opening a file with Mermaid blocks shows loading indicators that resolve to rendered diagrams.
  - AC-4b: Editing Mermaid source code in side-by-side mode triggers a fresh render of the changed diagram.

### REQ-005: No Scroll Re-render Issues in Side-by-Side Mode
- **Priority**: Should Have
- **User Type**: Markdown Editor
- **Requirement**: If the side-by-side editor mode shares the same preview rendering path, the fix must also prevent infinite re-render loops in that mode.
- **Rationale**: The same rendering pipeline is used in both modes; the fix should be structural enough to cover both, even though the bug has only been confirmed in preview-only mode.
- **Acceptance Criteria**:
  - AC-5a: Scrolling through Mermaid-containing content in side-by-side mode does not trigger visible re-render loops or jank.

### REQ-006: Non-Mermaid Block Stability During Scroll
- **Priority**: Should Have
- **User Type**: Markdown Viewer
- **Requirement**: Other block types that perform work on appearance (images with async loading, code blocks with syntax highlighting) must also not re-trigger their processing when scrolled in and out of view, if they are subject to the same LazyVStack recycling behavior.
- **Rationale**: The same LazyVStack recycling mechanism affects all block types. While Mermaid is the most expensive and therefore the most visible problem, similar (lesser) issues with other async blocks should be addressed if discovered during the fix.
- **Acceptance Criteria**:
  - AC-6a: Images that have already loaded do not show a loading placeholder when scrolled back into view.
  - AC-6b: Code blocks do not visibly re-highlight when scrolled back into view.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- NFR-1: Scrolling through a 100+ block document (including 10+ Mermaid diagrams) must remain responsive with no visible jank (subjective: "feels smooth").
- NFR-2: CPU usage during idle scrolling (no content changes) must not exceed baseline levels (no runaway rendering work).
- NFR-3: Memory usage for cached Mermaid rendered images must remain bounded -- caching strategy must not cause unbounded memory growth for very large documents.

### 6.2 Security Requirements

- No additional security requirements beyond existing constraints (Mermaid rendering already sandboxed in JavaScriptCore actor).

### 6.3 Usability Requirements

- NFR-4: The user must not perceive any difference in the visual presentation of Mermaid diagrams (same quality, same appearance).
- NFR-5: Mermaid zoom/pan interaction (MagnifyGesture, click-to-activate) must continue to work identically after the fix.

### 6.4 Compliance Requirements

- No compliance requirements apply.

## 7. User Stories

### STORY-001: Smooth Scroll Through Mermaid-Heavy Document
- **As a** developer viewing a Markdown report containing multiple Mermaid diagrams
- **I want** to scroll freely through the document without triggering re-renders
- **So that** the app remains responsive and I can read the full document smoothly

**Acceptance (BDD)**:
- GIVEN a Markdown file with 5+ Mermaid diagram blocks is open in preview mode
- WHEN the user scrolls up and down through the entire document at varying speeds
- THEN all Mermaid diagrams display their rendered images without flickering, re-rendering, or application jank

### STORY-002: Fast Scroll Without Crash
- **As a** developer quickly scanning a long Markdown document
- **I want** to scroll rapidly (fast flick) without the app freezing or crashing
- **So that** I can quickly navigate to the section I need

**Acceptance (BDD)**:
- GIVEN a Markdown file with Mermaid diagrams is open in preview mode
- WHEN the user performs rapid scroll gestures (fast flicks) through the document
- THEN the app remains responsive and does not freeze or crash

### STORY-003: Return to Previously Viewed Mermaid Diagram
- **As a** developer scrolling back up to a Mermaid diagram I saw earlier
- **I want** the diagram to appear instantly without a loading state
- **So that** my reading flow is not interrupted

**Acceptance (BDD)**:
- GIVEN a Mermaid diagram has been rendered and the user scrolled past it
- WHEN the user scrolls back to bring that diagram into view
- THEN the diagram appears immediately with its previously rendered image, with no loading indicator or re-render

## 8. Business Rules

- BR-1: Mermaid diagrams must only re-render when their source code content changes, never due to scroll position or view lifecycle events.
- BR-2: Cached rendered output must be invalidated when the underlying Mermaid source code changes (e.g., file reload, editor changes).
- BR-3: The fix must not introduce any WKWebView usage (per project charter constraint).

## 9. Dependencies & Constraints

| Dependency | Type | Impact |
|------------|------|--------|
| MermaidRenderer actor + MermaidCache | Internal | Existing cache infrastructure may need to be leveraged or extended to serve rendered images to recycled views |
| LazyVStack view recycling | SwiftUI framework | The core trigger -- LazyVStack destroys views when off-screen and recreates them when scrolled back, re-firing .task modifiers |
| @Observable / @Environment(AppState) | SwiftUI framework | Computed property access (e.g., appState.theme.colors) during body evaluation may contribute to unnecessary invalidation if observation tracking is too broad |
| SwiftDraw SVG rasterization | External dependency | Part of the Mermaid pipeline; expensive operation that must not be repeated unnecessarily |

## 10. Clarifications Log

| Question | Answer | Source |
|----------|--------|--------|
| Does the bug occur in preview-only mode, side-by-side, or both? | Confirmed in preview-only mode; side-by-side not yet tested | User response |
| Does it happen with all content types? | Appears to happen specifically around Mermaid content | User response |
| What is the severity when triggered? | Fast scrolling causes app to become unresponsive or crash | User response |
| Is this a recent regression? | No, longstanding issue | User response |
| What is the acceptance bar for scroll performance? | No specific FPS target; "no visible jank" and "scrolling should not crash the app" | User response |
| Is there a parent PRD? | No direct PRD; relates to the mermaid-rendering PRD tangentially but this is a bug fix, not a feature iteration | Agent assessment |
