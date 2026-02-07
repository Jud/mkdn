# Development Tasks: Mermaid Diagram Rendering Re-Architecture

**Feature ID**: mermaid-rearchitect
**Status**: In Progress
**Progress**: 27% (4 of 15 tasks)
**Estimated Effort**: 5 days
**Started**: 2026-02-07

## Overview

Replace the existing four-stage Mermaid rendering pipeline (JavaScriptCore + beautiful-mermaid.js + SVGSanitizer + SwiftDraw rasterization + custom gesture system) with a WKWebView-per-diagram approach. Each Mermaid code block gets its own WKWebView that loads standard Mermaid.js in its native rendering environment. A click-to-focus interaction model provides scroll pass-through by default and zoom/pan when activated.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2, T3, T4, TD1-TD7] - Teardown, resources, enums, theme mapper, and docs are all independent
2. [T5, T7] - MermaidWebView depends on T2 (template), T3 (state enum), T4 (theme mapper); MarkdownPreviewView update depends on T1 (MermaidImageStore deleted)
3. [T6] - MermaidBlockView rewrite depends on T5 (MermaidWebView)
4. [T9] - Tests depend on T5, T6

**Dependencies:**

- T5 -> [T2, T3, T4] (interface: MermaidWebView loads the HTML template and uses MermaidRenderState + MermaidThemeMapper)
- T6 -> T5 (interface: MermaidBlockView uses MermaidWebView)
- T7 -> T1 (data: MermaidImageStore reference deleted in T1)
- T9 -> [T5, T6] (build: tests import and exercise new components)

**Critical Path**: T2 -> T5 -> T6 -> T9

## Task Breakdown

### Teardown and Foundation

- [x] **T1**: Delete old Mermaid pipeline files, gesture files, test files, and remove SwiftDraw dependency from Package.swift `[complexity:medium]`

    **Reference**: [design.md#39-files-deleted](design.md#39-files-deleted)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] Delete source files: MermaidRenderer.swift, SVGSanitizer.swift, MermaidCache.swift, MermaidImageStore.swift, ScrollPhaseMonitor.swift, GestureIntentClassifier.swift, DiagramPanState.swift
    - [x] Delete test files: SVGSanitizerTests.swift, MermaidCacheTests.swift, MermaidImageStoreTests.swift, MermaidRendererTests.swift, GestureIntentClassifierTests.swift, DiagramPanStateTests.swift
    - [x] Delete old Resources/mermaid.min.js (beautiful-mermaid)
    - [x] Remove SwiftDraw package dependency from Package.swift
    - [x] Remove JXKit package dependency from Package.swift (if present)
    - [x] Remove SwiftDraw and JXKit from target dependency lists in Package.swift
    - [x] Remove old resource copy rules for mermaid.min.js in Package.swift
    - [x] No dead imports or references to removed code remain in the codebase
    - [x] Project compiles after removal (Mermaid blocks may show placeholder/error)

    **Implementation Summary**:

    - **Files**: `Package.swift`, `mkdn/Features/Viewer/Views/MermaidBlockView.swift`, `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`, `mkdn/App/DocumentState.swift` (modified); 7 source files, 6 test files, 1 resource file (deleted); `mkdn/Core/Gesture/` directory (removed)
    - **Approach**: Deleted all old pipeline files (MermaidRenderer, SVGSanitizer, MermaidCache, MermaidImageStore, ScrollPhaseMonitor, GestureIntentClassifier, DiagramPanState) and their tests. Removed SwiftDraw from Package.swift dependencies and target deps. Removed old resource copy rule. Replaced MermaidBlockView with a placeholder view. Cleaned up MermaidImageStore references in MarkdownPreviewView and DocumentState. JXKit was not in Package.swift (codebase used raw JavaScriptCore).
    - **Deviations**: JXKit was not present in Package.swift (only referenced in KB docs); actual import was `import JavaScriptCore` in MermaidRenderer.swift which was deleted. Also cleaned up MermaidImageStore references in MarkdownPreviewView and DocumentState (formally T7 scope, but required for T1 compilation AC).
    - **Tests**: 100/100 passing (0 failures)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

- [x] **T2**: Bundle standard Mermaid.js and create HTML rendering template `[complexity:medium]`

    **Reference**: [design.md#36-html-template-mermaid-templatehtml](design.md#36-html-template-mermaid-templatehtml)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] Standard mermaid.min.js is placed at mkdn/Resources/mermaid.min.js
    - [x] mermaid-template.html is created at mkdn/Resources/mermaid-template.html per design spec
    - [x] Template includes `__MERMAID_CODE__` and `__THEME_VARIABLES__` token placeholders
    - [x] Template includes sizeReport, renderComplete, and renderError message handlers
    - [x] Template includes reRenderWithTheme function for theme changes
    - [x] Template body has transparent background and overflow hidden
    - [x] `.copy("Resources/mermaid.min.js")` and `.copy("Resources/mermaid-template.html")` added to Package.swift resources
    - [x] Resources are accessible via Bundle.module at runtime

    **Implementation Summary**:

    - **Files**: `Package.swift` (modified), `mkdn/Resources/mermaid.min.js` (created), `mkdn/Resources/mermaid-template.html` (created)
    - **Approach**: Downloaded standard Mermaid.js v11.12.2 from jsDelivr CDN. Created HTML template with three token placeholders: `__MERMAID_CODE__` (HTML-escaped for pre tag), `__MERMAID_CODE_JS__` (JS-escaped for originalCode variable), and `__THEME_VARIABLES__` (JSON object). Template includes render(), reRenderWithTheme(), and three WKScriptMessageHandler callbacks (sizeReport, renderComplete, renderError). Added `.copy()` resource rules to Package.swift.
    - **Deviations**: Added `__MERMAID_CODE_JS__` as a third token (design spec listed two). This separates HTML-escaped content (for the pre tag) from JS-escaped content (for the template literal variable used in re-renders). See field-notes.md for details.
    - **Tests**: 120/120 passing (0 failures)

- [x] **T3**: Create MermaidRenderState and MermaidError enums `[complexity:simple]`

    **Reference**: [design.md#34-mermaidrenderstate](design.md#34-mermaidrenderstate)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] MermaidRenderState enum created at mkdn/Core/Mermaid/MermaidRenderState.swift with cases: loading, rendered, error(String)
    - [x] MermaidRenderState conforms to Equatable
    - [x] MermaidError enum created at mkdn/Core/Mermaid/MermaidError.swift with cases: templateNotFound, renderFailed(String)
    - [x] MermaidError conforms to LocalizedError with descriptive errorDescription
    - [x] Both files compile cleanly with Swift 6 strict concurrency

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Mermaid/MermaidRenderState.swift`, `mkdn/Core/Mermaid/MermaidError.swift`
    - **Approach**: Created two enum types per design spec. MermaidRenderState has three cases (loading, rendered, error) and conforms to Equatable and Sendable. MermaidError has two cases (templateNotFound, renderFailed) and conforms to LocalizedError with descriptive errorDescription and Sendable.
    - **Deviations**: None
    - **Tests**: 100/100 passing (existing tests unaffected)

- [x] **T4**: Create MermaidThemeMapper utility for theme-to-Mermaid variable mapping `[complexity:medium]`

    **Reference**: [design.md#37-theme-to-mermaid-variable-mapping](design.md#37-theme-to-mermaid-variable-mapping)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] MermaidThemeMapper enum created at mkdn/Core/Mermaid/MermaidThemeMapper.swift
    - [x] Static method themeVariablesJSON(for:) returns valid JSON string of Mermaid themeVariables
    - [x] All 26 Mermaid theme variables from the design spec mapping table are included
    - [x] Solarized Dark theme produces correct hex values per design spec
    - [x] Solarized Light theme produces correct hex values per design spec
    - [x] Hardcoded hex lookup keyed by AppTheme case (no runtime Color-to-hex conversion)
    - [x] Output is valid JSON parseable by JavaScript

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Mermaid/MermaidThemeMapper.swift`
    - **Approach**: Created a public enum with a static `themeVariablesJSON(for:)` method that returns a JSON string. Uses hardcoded `[String: String]` dictionaries for each AppTheme case, keyed to Solarized hex values from the design spec. Serializes via JSONSerialization with sortedKeys for deterministic output. Also exposes an internal `themeVariables(for:)` method returning the raw dictionary for testability.
    - **Deviations**: None
    - **Tests**: 100/100 passing (existing tests unaffected)

### WKWebView Integration

- [ ] **T5**: Create MermaidWebView (NSViewRepresentable + MermaidContainerView + Coordinator) `[complexity:complex]`

    **Reference**: [design.md#31-mermaidcontainerview-nsview](design.md#31-mermaidcontainerview-nsview)

    **Effort**: 8 hours

    **Acceptance Criteria**:

    - [ ] MermaidContainerView NSView subclass with hitTest gating based on allowsInteraction flag
    - [ ] MermaidWebView NSViewRepresentable created at mkdn/Core/Mermaid/MermaidWebView.swift
    - [ ] Shared static WKProcessPool for all diagram instances
    - [ ] WKUserContentController with sizeReport, renderComplete, renderError message handlers
    - [ ] Coordinator implements WKScriptMessageHandler to route messages and update bindings
    - [ ] Coordinator implements WKNavigationDelegate to block all non-initial navigation
    - [ ] Template loading with token substitution for __MERMAID_CODE__ (HTML escaped) and __THEME_VARIABLES__
    - [ ] loadHTMLString called with baseURL pointing to resource directory for local mermaid.min.js resolution
    - [ ] updateNSView detects theme changes and re-renders via evaluateJavaScript (in-place, no WKWebView recreation)
    - [ ] updateNSView updates allowsInteraction on MermaidContainerView when focus changes
    - [ ] Click-outside detection via NSEvent.addLocalMonitorForEvents installed/removed with focus state
    - [ ] WKWebView configured with isOpaque=false, transparent background, underPageBackgroundColor=.clear
    - [ ] Compiles with Swift 6 strict concurrency (@preconcurrency import WebKit if needed)

- [ ] **T7**: Update MarkdownPreviewView to remove MermaidImageStore reference `[complexity:simple]`

    **Reference**: [design.md#311-files-modified](design.md#311-files-modified)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [ ] Remove MermaidImageStore.shared.removeAll() call on theme change in MarkdownPreviewView.swift
    - [ ] Remove any import of MermaidImageStore if present
    - [ ] MarkdownPreviewView compiles and functions correctly after change

### View Layer

- [ ] **T6**: Rewrite MermaidBlockView with WKWebView-based rendering and focus interaction model `[complexity:medium]`

    **Reference**: [design.md#33-mermaidblockview-swiftui-view](design.md#33-mermaidblockview-swiftui-view)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] MermaidBlockView rewritten at mkdn/Features/Viewer/Views/MermaidBlockView.swift
    - [ ] @State properties: isFocused (Bool), renderedHeight (CGFloat, default 200), renderState (MermaidRenderState)
    - [ ] ZStack layout with loading/error overlay on top of MermaidWebView
    - [ ] MermaidWebView opacity 0 until renderState == .rendered, then 1 (prevents blank flash)
    - [ ] Frame: maxWidth .infinity, height capped at min(renderedHeight, 600)
    - [ ] Clipped with RoundedRectangle(cornerRadius: 6)
    - [ ] When focused: 2pt accent-colored border overlay using theme.colors.accent
    - [ ] Background: theme.colors.backgroundSecondary
    - [ ] .onTapGesture sets isFocused = true
    - [ ] .onKeyPress(.escape) sets isFocused = false (macOS 14+ API)
    - [ ] Loading state shows ProgressView spinner
    - [ ] Error state shows warning icon and descriptive error message
    - [ ] Theme changes trigger re-render via MermaidWebView updateNSView path

### Testing

- [ ] **T9**: Write unit tests for MermaidThemeMapper and HTML template token substitution `[complexity:medium]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] MermaidThemeMapperTests created at mkdnTests/Unit/Core/MermaidThemeMapperTests.swift
    - [ ] Test: themeVariablesJSON output for Solarized Dark contains correct hex values
    - [ ] Test: themeVariablesJSON output for Solarized Light contains correct hex values
    - [ ] Test: output is valid JSON (parseable by JSONSerialization)
    - [ ] Test: all 26 required Mermaid themeVariable keys are present in output
    - [ ] Test: dark and light themes produce different variable values
    - [ ] MermaidHTMLTemplateTests created at mkdnTests/Unit/Core/MermaidHTMLTemplateTests.swift
    - [ ] Test: token substitution produces HTML with no remaining `__` token placeholders
    - [ ] Test: HTML entity escaping works for special characters (<, >, &, ") in diagram code
    - [ ] Test: MermaidRenderState equatable conformance works correctly for all cases
    - [ ] All tests use Swift Testing (@Test, #expect, @Suite)
    - [ ] All tests compile and pass

### User Docs

- [ ] **TD1**: Update CLAUDE.md - Critical Rules `[complexity:simple]`

    **Reference**: [design.md#9-documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: CLAUDE.md

    **Section**: Critical Rules

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Critical Rules section notes the WKWebView exception for Mermaid diagram rendering
    - [ ] Exception is clearly scoped: WKWebView allowed ONLY for Mermaid diagrams, nowhere else
    - [ ] Existing "NO WKWebView" rule is updated (not just contradicted)

- [ ] **TD2**: Update architecture.md - Mermaid Diagrams `[complexity:simple]`

    **Reference**: [design.md#9-documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: .rp1/context/architecture.md

    **Section**: Mermaid Diagrams

    **KB Source**: architecture.md:Mermaid Diagrams

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Mermaid Diagrams section reflects WKWebView-per-diagram approach
    - [ ] Old pipeline description (JSC + beautiful-mermaid + SwiftDraw) is replaced
    - [ ] New component list: MermaidBlockView, MermaidWebView, MermaidContainerView, mermaid-template.html

- [ ] **TD3**: Update architecture.md - Concurrency Model `[complexity:simple]`

    **Reference**: [design.md#9-documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: .rp1/context/architecture.md

    **Section**: Concurrency Model

    **KB Source**: architecture.md:Concurrency Model

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] MermaidRenderer actor reference is removed
    - [ ] WKWebView @MainActor usage is documented
    - [ ] Section accurately reflects current concurrency approach

- [ ] **TD4**: Update modules.md - Core/Mermaid `[complexity:simple]`

    **Reference**: [design.md#9-documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: .rp1/context/modules.md

    **Section**: Core/Mermaid

    **KB Source**: modules.md:Mermaid

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Core/Mermaid file inventory updated: MermaidWebView.swift, MermaidRenderState.swift, MermaidError.swift, MermaidThemeMapper.swift
    - [ ] Old files removed from inventory: MermaidRenderer.swift, SVGSanitizer.swift, MermaidCache.swift, MermaidImageStore.swift
    - [ ] Purpose descriptions reflect new WKWebView-based architecture

- [ ] **TD5**: Update modules.md - Dependencies `[complexity:simple]`

    **Reference**: [design.md#9-documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: .rp1/context/modules.md

    **Section**: Dependencies

    **KB Source**: modules.md:Dependencies

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] SwiftDraw row removed from dependencies table
    - [ ] JXKit row removed from dependencies table
    - [ ] WebKit (system framework) added with purpose and usage location
    - [ ] Mermaid.js (bundled resource) noted

- [ ] **TD6**: Update patterns.md - Actor Pattern (Mermaid) `[complexity:simple]`

    **Reference**: [design.md#9-documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: .rp1/context/patterns.md

    **Section**: Actor Pattern (Mermaid)

    **KB Source**: patterns.md:Actor Pattern

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Actor Pattern (Mermaid) section replaced with NSViewRepresentable + WKWebView pattern
    - [ ] Example code reflects MermaidWebView/Coordinator pattern
    - [ ] Anti-patterns section updated: WKWebView exception noted for Mermaid diagrams

- [ ] **TD7**: Update concept_map.md - User Workflows `[complexity:simple]`

    **Reference**: [design.md#9-documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: .rp1/context/concept_map.md

    **Section**: User Workflows

    **KB Source**: concept_map.md:User Workflows

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Diagram review workflow description updated to reflect click-to-focus interaction model
    - [ ] Old gesture classification references removed

## Acceptance Criteria Checklist

### FR-001: Teardown of Existing Mermaid Pipeline
- [ ] AC-001.1: Old source files deleted (MermaidRenderer, SVGSanitizer, MermaidCache, MermaidImageStore, ScrollPhaseMonitor, GestureIntentClassifier, DiagramPanState)
- [ ] AC-001.2: All corresponding test files deleted
- [ ] AC-001.3: SwiftDraw and JXKit removed from Package.swift
- [ ] AC-001.4: beautiful-mermaid.js resource deleted and removed from Package.swift
- [ ] AC-001.5: App builds successfully after removal
- [ ] AC-001.6: No dead imports or references to removed code remain

### FR-002: WKWebView-Per-Diagram Rendering
- [ ] AC-002.1: Each Mermaid code block results in a separate WKWebView instance
- [ ] AC-002.2: WKWebView loads self-contained HTML template with standard Mermaid.js
- [ ] AC-002.3: All five diagram types render correctly (flowchart, sequence, state, class, ER)
- [ ] AC-002.4: WKWebView wrapped in NSViewRepresentable
- [ ] AC-002.5: WKWebView created and used on main actor (Swift 6 concurrency)

### FR-003: Theme-Aware Diagram Rendering
- [ ] AC-003.1: HTML template accepts theme colors as Mermaid.js themeVariables
- [ ] AC-003.2: Solarized Dark diagrams use dark-theme colors
- [ ] AC-003.3: Solarized Light diagrams use light-theme colors
- [ ] AC-003.4: WKWebView background transparent or theme-matching, no white flash

### FR-004: Diagram Re-Rendering on Theme Change
- [ ] AC-004.1: After theme switch, all visible diagrams display new theme colors
- [ ] AC-004.2: Re-rendering occurs without user scroll/reload

### FR-005: Scroll Pass-Through for Unfocused Diagrams
- [ ] AC-005.1: Scrolling passes smoothly through unfocused diagrams
- [ ] AC-005.2: No custom scroll-phase monitoring or gesture classification heuristics

### FR-006: Click-to-Focus Interaction Model
- [ ] AC-006.1: Clicking a diagram transitions to focused state
- [ ] AC-006.2: Visual focus indicator (border/glow) visible when focused
- [ ] AC-006.3: Pinch-to-zoom works in focused state
- [ ] AC-006.4: Two-finger pan works in focused state
- [ ] AC-006.5: Escape unfocuses and returns scroll control
- [ ] AC-006.6: Clicking outside unfocuses

### FR-007: Async Rendering with Loading and Error States
- [ ] AC-007.1: Loading spinner displayed while rendering
- [ ] AC-007.2: Warning icon and error message on render failure
- [ ] AC-007.3: Mermaid.js parse errors caught and surfaced
- [ ] AC-007.4: One diagram failure does not affect others
- [ ] AC-007.5: No diagram scenario causes app crash

### FR-008: Auto-Sizing of Diagram Views
- [ ] AC-008.1: Rendered size reported from JS to Swift via WKScriptMessageHandler
- [ ] AC-008.2: Host view sizes to match reported dimensions
- [ ] AC-008.3: Maximum height enforced (600pt)
- [ ] AC-008.4: Short diagrams display at natural height

### FR-009: HTML Template for Mermaid Rendering
- [ ] AC-009.1: Mermaid.js bundled as local resource
- [ ] AC-009.2: Template renders without network access
- [ ] AC-009.3: Template accepts theme configuration at render time
- [ ] AC-009.4: Template reports rendered dimensions to Swift
- [ ] AC-009.5: Template background transparent or theme-matching

### FR-010: Dependency Cleanup in Package.swift
- [ ] AC-010.1: SwiftDraw removed from Package.swift
- [ ] AC-010.2: JXKit removed from Package.swift
- [ ] AC-010.3: Old mermaid.min.js resource rule removed
- [ ] AC-010.4: Standard Mermaid.js added as bundled resource
- [ ] AC-010.5: Project builds and non-Mermaid tests pass

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
