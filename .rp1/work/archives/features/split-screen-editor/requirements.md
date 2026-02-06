# Requirements Specification: Split-Screen Editor

**Feature ID**: split-screen-editor
**Parent PRD**: [Split-Screen Editor](../../prds/split-screen-editor.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

The Split-Screen Editor provides a side-by-side Markdown editing experience within mkdn, allowing developers to toggle between a full-width preview-only reading mode and a split-pane editing mode where they can write Markdown on the left and see a live-rendered preview on the right. This feature completes the core "open, render beautifully, edit, close" workflow described in the project charter.

## 2. Business Context

### 2.1 Problem Statement

Developers working with LLMs and coding agents frequently need to make quick edits to Markdown artifacts -- documentation, reports, specs, and notes. Currently, mkdn supports preview-only viewing but lacks an editing mode, forcing developers to switch to a separate editor (VS Code, terminal-based editors) for even small changes. This context-switching interrupts the developer workflow and undermines the "open, edit, close" promise.

### 2.2 Business Value

- Eliminates context-switching between mkdn (for viewing) and a separate editor (for editing)
- Completes the core user workflow loop: open from terminal, view, edit, save, close
- Differentiates mkdn from simpler Markdown viewers that are read-only
- Reinforces the "daily driver" success criterion by making mkdn sufficient for light editing tasks
- Live preview during editing provides immediate visual feedback, reducing formatting errors

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Workflow completion | Users can open, edit, save, and close a Markdown file entirely within mkdn | Manual validation |
| Edit-to-preview latency | Live preview updates feel instant for typical Markdown files (under ~200ms perceived delay) | Subjective user testing |
| Mode toggle smoothness | Transition between preview-only and side-by-side feels physically natural with no visual jank | Subjective user testing |
| Daily driver adoption | The creator uses mkdn for editing Markdown artifacts in their daily workflow | Personal usage tracking |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relationship to Feature |
|-----------|-------------|------------------------|
| Terminal Developer | Developer who launches mkdn from the command line to view Markdown files produced by LLMs and coding agents | Primary user. Needs to quickly make edits without leaving mkdn. |
| Markdown Author | Developer writing or refining Markdown documentation, specs, or notes | Primary user. Needs a comfortable editing experience with live preview feedback. |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project Creator | Daily-driver quality editing experience; consistent with design philosophy of obsessive sensory detail |
| End Users (Terminal Developers) | Minimal friction editing; fast mode switching; reliable save; no data loss |

## 4. Scope Definition

### 4.1 In Scope

- Toggle between preview-only and side-by-side editing modes via toolbar control
- Resizable split pane with editor on the left and rendered preview on the right
- Plain-text Markdown editing with monospaced font and theme-consistent styling
- Live preview re-rendering as the user types
- File save (Cmd+S) with unsaved-changes tracking and visual indicator
- File load populating both editor text and preview pane
- Theme-aware editor pane (Solarized Dark/Light)
- File-change detection continuing to function in edit mode
- Polished animations for mode transitions, divider interaction, unsaved indicator, and focus transitions

### 4.2 Out of Scope

- Syntax highlighting within the editor pane (code coloring in the text editor itself)
- Synchronized scroll position between editor and preview
- Line numbers or gutter in the editor pane
- Multiple file tabs or additional split panes
- Auto-save or timed save
- Markdown formatting toolbar (bold/italic/link buttons)
- Vim/Emacs keybinding modes
- Export to other formats (PDF, HTML)

### 4.3 Assumptions

| ID | Assumption | Impact if Wrong |
|----|------------|-----------------|
| A1 | The platform text editing component provides sufficient styling control for theme-consistent foreground and background colors | May require a lower-level text editing approach with more customization options |
| A2 | Live preview re-rendering is fast enough with debouncing for typical Markdown files | Large documents may require incremental rendering or lazy approaches |
| A3 | A split view component provides smooth, polished divider interaction out of the box | May require a custom divider implementation for snap points and hover feedback |
| A4 | Breathing animation at approximately 12 cycles per minute is achievable with standard animation APIs | May require custom timing mechanisms for precise rhythm control |
| A5 | File-change detection and editor state coexist without conflicts | Reload-while-editing needs careful user experience design to avoid data loss |

## 5. Functional Requirements

### REQ-SSE-001: View Mode Toggle

- **Priority**: Must Have
- **User Type**: Terminal Developer, Markdown Author
- **Requirement**: The user must be able to toggle between preview-only mode (full-width rendered Markdown) and side-by-side mode (editor + preview) via a toolbar control. The default mode when opening a file is preview-only.
- **Rationale**: Developers need to switch fluidly between reading and editing without friction. Preview-only as default preserves the "quick view" workflow for users who just want to read.
- **Acceptance Criteria**:
  - AC1: A toolbar control is visible that allows switching between preview-only and side-by-side modes
  - AC2: Selecting preview-only mode displays full-width rendered Markdown with no editor visible
  - AC3: Selecting side-by-side mode displays the editor pane on the left and the preview pane on the right
  - AC4: The default mode on file open is preview-only
  - AC5: The mode toggle is accessible via keyboard navigation

### REQ-SSE-002: Split Pane Layout

- **Priority**: Must Have
- **User Type**: Markdown Author
- **Requirement**: In side-by-side mode, the layout must present a horizontal split with the editor on the left and the rendered preview on the right, separated by a user-resizable divider. The default split ratio must be 50/50.
- **Rationale**: A balanced default split gives equal space to writing and previewing. Resizability lets users adjust based on their current focus (more editing space vs. more preview space).
- **Acceptance Criteria**:
  - AC1: The editor pane appears on the left and the preview pane appears on the right
  - AC2: The divider between panes is draggable by the user to resize the split ratio
  - AC3: The default split ratio is approximately 50/50
  - AC4: The layout respects the window's minimum size constraints

### REQ-SSE-003: Plain-Text Markdown Editing

- **Priority**: Must Have
- **User Type**: Markdown Author
- **Requirement**: The editor pane must provide plain-text editing of Markdown content with a monospaced font and theme-consistent foreground and background colors. Standard macOS text editing capabilities (undo, redo, cut, copy, paste, text selection) must be supported.
- **Rationale**: Developers expect familiar text editing behavior. Monospaced font and theme-consistent colors create a comfortable editing environment that feels cohesive with the rest of the application.
- **Acceptance Criteria**:
  - AC1: The editor displays Markdown content as plain text in a monospaced font
  - AC2: The editor foreground and background colors match the active Solarized theme (Dark or Light)
  - AC3: Undo (Cmd+Z) and redo (Cmd+Shift+Z) function correctly
  - AC4: Cut (Cmd+X), copy (Cmd+C), and paste (Cmd+V) function correctly
  - AC5: Text selection via mouse and keyboard (Shift+Arrow, Cmd+A) functions correctly

### REQ-SSE-004: Live Preview

- **Priority**: Must Have
- **User Type**: Markdown Author
- **Requirement**: The preview pane must re-render in real time as the user types in the editor. The editor text is the single source of truth; changes in the editor must flow through the existing Markdown rendering pipeline to update the preview.
- **Rationale**: Immediate visual feedback is essential for a productive editing experience. Developers need to see how their Markdown will render as they write it, without manual refresh steps.
- **Acceptance Criteria**:
  - AC1: Typing in the editor causes the preview pane to update with the newly rendered Markdown
  - AC2: Preview updates feel responsive (no perceptible lag for typical Markdown files)
  - AC3: The preview uses the same rendering pipeline and visual output as the preview-only mode
  - AC4: Rapid typing does not cause visual jank or application unresponsiveness

### REQ-SSE-005: File Save

- **Priority**: Must Have
- **User Type**: Markdown Author
- **Requirement**: The user must be able to save the current editor content to disk using Cmd+S. After a successful save, the unsaved-changes indicator must be cleared.
- **Rationale**: Cmd+S is the universally expected save shortcut on macOS. Developers need a reliable, familiar way to persist their edits.
- **Acceptance Criteria**:
  - AC1: Pressing Cmd+S writes the current editor text content to the original file path on disk
  - AC2: After a successful save, the unsaved-changes indicator is no longer visible
  - AC3: If the save fails (e.g., permissions issue), the user is informed and the unsaved indicator remains

### REQ-SSE-006: Unsaved Changes Tracking

- **Priority**: Must Have
- **User Type**: Markdown Author
- **Requirement**: When the editor text diverges from the last-saved (or last-loaded) content, a visual indicator must be displayed to inform the user that unsaved changes exist.
- **Rationale**: Developers need to know at a glance whether their changes have been saved. This prevents accidental data loss from closing a file without saving.
- **Acceptance Criteria**:
  - AC1: A visual indicator appears when the editor text differs from the last-saved content
  - AC2: The indicator disappears after a successful save (Cmd+S)
  - AC3: The indicator appears immediately when the user makes any edit to a previously saved file
  - AC4: Opening a file and making no edits does not show the unsaved indicator

### REQ-SSE-007: File Load into Editor

- **Priority**: Must Have
- **User Type**: Terminal Developer, Markdown Author
- **Requirement**: When a file is opened (via CLI argument, drag-and-drop, or open dialog), the file content must populate both the editor text and the preview pane.
- **Rationale**: The editor and preview must always start in sync when a file is loaded. Users expect that opening a file makes it immediately available for both viewing and editing.
- **Acceptance Criteria**:
  - AC1: Opening a file via `mkdn file.md` populates the editor with the file's text content
  - AC2: Opening a file via drag-and-drop populates the editor with the file's text content
  - AC3: Opening a file via the open dialog populates the editor with the file's text content
  - AC4: The preview pane displays the rendered version of the same content
  - AC5: Editor and preview are in sync immediately after file load

### REQ-SSE-008: File-Change Detection in Edit Mode

- **Priority**: Must Have
- **User Type**: Markdown Author
- **Requirement**: The existing file-change detection mechanism must continue to function when the user is in side-by-side editing mode. If the file changes on disk while the user is editing, the outdated indicator must appear. The user must manually decide whether to reload the file, which would replace the current editor content.
- **Rationale**: Terminal developers often have external processes (LLMs, build scripts) that modify Markdown files. They need to be aware when the on-disk version diverges from what they are editing, and they need explicit control over whether to reload to avoid losing in-progress edits.
- **Acceptance Criteria**:
  - AC1: If the file is modified on disk while the editor is open, the outdated indicator appears
  - AC2: The outdated indicator is visible in both preview-only and side-by-side modes
  - AC3: Reloading the file replaces the editor text with the on-disk content
  - AC4: Reloading clears the outdated indicator
  - AC5: The user is not forced to reload; it is a manual action

### REQ-SSE-009: Theme-Aware Editor Pane

- **Priority**: Must Have
- **User Type**: Markdown Author
- **Requirement**: The editor pane must use foreground and background colors sourced from the active Solarized theme (Dark or Light), ensuring the editor visually matches the preview pane and the overall application aesthetic.
- **Rationale**: Visual cohesion between the editor and preview panes is essential for a polished, professional experience. Mismatched colors between panes would feel jarring and undermine the application's design philosophy.
- **Acceptance Criteria**:
  - AC1: The editor background color matches the active theme's background
  - AC2: The editor text color matches the active theme's foreground
  - AC3: Switching themes updates the editor pane colors immediately
  - AC4: The editor and preview panes appear visually cohesive when displayed side-by-side

### REQ-SSE-010: Mode Transition Animation

- **Priority**: Should Have
- **User Type**: Terminal Developer, Markdown Author
- **Requirement**: Toggling between preview-only and side-by-side modes must animate smoothly with a natural, physical-feeling transition. The editor pane should slide in and out rather than appearing or disappearing abruptly.
- **Rationale**: Per the project charter's design philosophy, every interactive element must be crafted with obsessive attention to sensory detail. A jarring mode swap would undermine the polished feel of the application.
- **Acceptance Criteria**:
  - AC1: Switching from preview-only to side-by-side shows the editor pane sliding in from the left
  - AC2: Switching from side-by-side to preview-only shows the editor pane sliding out to the left
  - AC3: The animation feels organic and spring-like, not mechanical or linear
  - AC4: The animation completes without visual glitches or layout jumps

### REQ-SSE-011: Divider Interaction Polish

- **Priority**: Should Have
- **User Type**: Markdown Author
- **Requirement**: The resizable divider between the editor and preview panes must feel polished, with smooth drag response, sensible snap points (e.g., 30/70, 50/50, 70/30), and visual feedback on hover (such as a subtle highlight or width change).
- **Rationale**: The divider is a frequently used interaction point. A polished divider reinforces the application's attention to detail and makes the editing experience feel premium.
- **Acceptance Criteria**:
  - AC1: Dragging the divider resizes the panes smoothly without lag
  - AC2: The divider snaps to sensible ratio points (approximately 30/70, 50/50, 70/30) when dragged near them
  - AC3: Hovering over the divider provides visual feedback (highlight, cursor change, or width change)
  - AC4: The divider respects minimum pane widths so neither pane collapses to zero

### REQ-SSE-012: Unsaved Indicator Animation

- **Priority**: Should Have
- **User Type**: Markdown Author
- **Requirement**: The unsaved-changes indicator must use a subtle breathing animation timed to human rhythms (approximately 12 cycles per minute) rather than being a static icon. The animation should draw attention without being distracting.
- **Rationale**: Per the project charter's design philosophy, animations must be timed to human rhythms. A breathing indicator is more noticeable than a static dot but less intrusive than a blinking or flashing animation.
- **Acceptance Criteria**:
  - AC1: The unsaved-changes indicator pulses with a gentle breathing rhythm
  - AC2: The animation rate is approximately 12 cycles per minute (one cycle every 5 seconds)
  - AC3: The animation is subtle enough to not distract from editing but noticeable enough to inform the user
  - AC4: The animation uses the same design language as other animated indicators in the application

### REQ-SSE-013: Focus Transition Polish

- **Priority**: Could Have
- **User Type**: Markdown Author
- **Requirement**: Moving focus between the editor and preview panes should feel natural with smooth visual feedback. Focus indicators should be subtle and theme-consistent rather than harsh system-default focus rings.
- **Rationale**: Per the design philosophy, every visual element deserves attention. Harsh focus rings feel out of place in a carefully themed application.
- **Acceptance Criteria**:
  - AC1: Moving focus between panes provides a subtle visual indication of which pane is focused
  - AC2: The focus indicator uses theme-consistent colors
  - AC3: No harsh or system-default focus rings are visible on the panes

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Expectation | Target |
|-------------|--------|
| Live preview update latency | Perceived as instant for typical Markdown files; debounced during rapid typing to prevent jank |
| Mode toggle responsiveness | Animation begins immediately on user action with no perceptible delay |
| Memory usage | Only the current document's rendered state is held; no unbounded caching of previous renders |

### 6.2 Security Requirements

| Requirement | Description |
|-------------|-------------|
| File write safety | Save operations must write to the original file path only; no writes to unintended locations |
| Data integrity | Save must not corrupt file content; complete content must be written before the old file is replaced |

### 6.3 Usability Requirements

| Requirement | Description |
|-------------|-------------|
| Accessibility | VoiceOver support for the editor pane (provided by the native text editing component); keyboard-navigable mode toggle |
| Discoverability | The mode toggle must be clearly visible in the toolbar; unsaved and outdated indicators must be self-explanatory |
| Familiarity | Standard macOS keyboard shortcuts (Cmd+S, Cmd+Z, Cmd+Shift+Z, Cmd+C/V/X) must work as expected |

### 6.4 Compliance Requirements

| Requirement | Description |
|-------------|-------------|
| Platform | macOS 14.0+ (Sonoma) |
| Concurrency | Swift 6 strict concurrency; no data races |

## 7. User Stories

### STORY-SSE-001: Quick Edit from Terminal

**As a** Terminal Developer
**I want** to open a Markdown file from the terminal, switch to editing mode, make a quick change, and save
**So that** I can fix typos or update content without switching to a different editor

**Acceptance Scenarios**:

- GIVEN I have launched mkdn with a Markdown file from the terminal
  WHEN I toggle to side-by-side mode via the toolbar control
  THEN I see the editor pane appear on the left with the file's Markdown content and the rendered preview on the right

- GIVEN I am in side-by-side mode with a file loaded
  WHEN I edit the Markdown text in the editor pane
  THEN the preview pane updates to reflect my changes in real time

- GIVEN I have made edits to the file
  WHEN I press Cmd+S
  THEN the file is saved to disk and the unsaved-changes indicator disappears

### STORY-SSE-002: Review and Edit LLM Output

**As a** Terminal Developer
**I want** to view a Markdown artifact produced by a coding agent, see it rendered beautifully, and make targeted edits
**So that** I can refine LLM-generated documentation without leaving mkdn

**Acceptance Scenarios**:

- GIVEN I have opened a Markdown file generated by an LLM
  WHEN I view it in preview-only mode
  THEN I see the fully rendered Markdown with proper formatting, code blocks, and diagrams

- GIVEN I notice a section that needs editing
  WHEN I switch to side-by-side mode
  THEN I can locate the corresponding Markdown source in the editor and make my changes while watching the preview update

### STORY-SSE-003: Concurrent External Changes

**As a** Markdown Author
**I want** to be informed when the file I am editing is changed on disk by an external process
**So that** I can decide whether to incorporate those changes or continue with my current edits

**Acceptance Scenarios**:

- GIVEN I am editing a Markdown file in side-by-side mode
  WHEN an external process modifies the same file on disk
  THEN an outdated indicator appears informing me the on-disk version has changed

- GIVEN the outdated indicator is showing
  WHEN I choose to reload the file
  THEN the editor content is replaced with the updated on-disk content and the outdated indicator disappears

- GIVEN the outdated indicator is showing
  WHEN I choose not to reload and continue editing
  THEN my current editor content is preserved and I can save my version when ready

### STORY-SSE-004: Theme-Consistent Editing

**As a** Markdown Author
**I want** the editor pane to match my selected Solarized theme
**So that** the editing experience feels visually cohesive with the preview and the rest of the application

**Acceptance Scenarios**:

- GIVEN I have Solarized Dark theme active
  WHEN I switch to side-by-side mode
  THEN the editor pane uses the Solarized Dark background and foreground colors

- GIVEN I am in side-by-side mode
  WHEN I switch from Solarized Dark to Solarized Light
  THEN both the editor and preview panes update their colors immediately to match the new theme

### STORY-SSE-005: Resize Editor and Preview

**As a** Markdown Author
**I want** to resize the split between the editor and preview panes
**So that** I can allocate more space to whichever pane I am currently focused on

**Acceptance Scenarios**:

- GIVEN I am in side-by-side mode with the default 50/50 split
  WHEN I drag the divider to the right
  THEN the editor pane gets more space and the preview pane gets less space

- GIVEN I am dragging the divider
  WHEN I drag near a snap point (e.g., 70/30)
  THEN the divider snaps to that ratio for precise positioning

## 8. Business Rules

| Rule ID | Rule | Rationale |
|---------|------|-----------|
| BR-001 | The default view mode on file open is preview-only, not side-by-side | Preserves the "quick view" workflow; editing is an intentional action |
| BR-002 | Save (Cmd+S) writes to the original file path; no "Save As" in initial scope | Simplicity; the "open, edit, save, close" workflow targets in-place edits |
| BR-003 | Reload from disk is always a manual user action, never automatic | Prevents data loss; the user must explicitly choose to overwrite their edits |
| BR-004 | The editor pane is always on the left, the preview pane always on the right | Consistent mental model: source on left, output on right (matches code/output conventions) |
| BR-005 | Unsaved-changes tracking compares editor text to last-saved content, not last-loaded content (after a save, the baseline updates) | Accurate tracking after iterative save cycles |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| AppState | Internal | Central observable state; provides file content, view mode, theme |
| MarkdownRenderer | Internal | Existing Markdown parsing and rendering pipeline; editor text flows through this for live preview |
| FileWatcher | Internal | Existing file-change detection; must continue working in edit mode |
| Theme System | Internal | Solarized Dark/Light color definitions; editor pane reads from these |
| Existing Editor Scaffolding | Internal | SplitEditorView, MarkdownEditorView, EditorViewModel, ViewMode enum, ViewModePicker already exist as scaffolding |

### Constraints

| Constraint | Description |
|------------|-------------|
| No new external dependencies | This feature must be implemented using existing SPM dependencies; no new packages |
| Two-target layout | All editor code must reside in the mkdnLib library target |
| macOS 14.0+ | Must use APIs available on macOS Sonoma and later |

## 10. Clarifications Log

| # | Question | Resolution | Source |
|---|----------|------------|--------|
| 1 | What user types interact with this feature? | Terminal Developers who open files from CLI and need to make quick edits; Markdown Authors writing or refining documentation | Inferred from charter target users and PRD surface overview |
| 2 | What is the default view mode on file open? | Preview-only | PRD Functional Requirement 1 |
| 3 | What is the default split ratio? | 50/50 | PRD Functional Requirement 2 |
| 4 | Should the editor support syntax highlighting? | No, out of scope per PRD | PRD Out of Scope |
| 5 | Should scroll positions be synchronized between editor and preview? | No, out of scope per PRD | PRD Out of Scope |
| 6 | What happens when file changes on disk during editing? | Outdated indicator appears; user manually decides whether to reload | PRD Functional Requirement 8 |
| 7 | What is the breathing animation rate for the unsaved indicator? | Approximately 12 cycles per minute (one cycle every 5 seconds) | Charter Design Philosophy, PRD Design Requirement 3 |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD selection | split-screen-editor.md | Exact filename match with FEATURE_ID |
| Requirements source | Derived from PRD + charter (no raw REQUIREMENTS provided) | REQUIREMENTS parameter was empty; PRD provides comprehensive functional, design, and non-functional requirements |
| Priority assignment | Mode toggle, split layout, editing, live preview, save, unsaved tracking, file load, file-change detection, theme-aware editor all set to Must Have; animations set to Should Have; focus polish set to Could Have | Must Have items are core to the "open, edit, save, close" workflow; Should Have items fulfill the charter design philosophy; Could Have items are polish enhancements |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| Empty REQUIREMENTS parameter | Derived all requirements from PRD functional requirements, design requirements, and non-functional requirements combined with charter context | PRD split-screen-editor.md + charter.md |
| Measurable success metrics not specified in PRD | Defined subjective metrics (perceived latency, daily driver adoption) aligned with charter success criteria ("personal daily-driver use") | Charter Success Criteria |
| Save failure handling not specified in PRD | Inferred that save failures should inform the user and preserve the unsaved indicator | Conservative default: never silently lose data |
| Whether mode preference persists across sessions | Not included in scope; defaulting to stateless (always opens in preview-only) | PRD states default is preview-only; no session persistence mentioned; conservative default |
| Minimum pane widths for divider constraints | Included as acceptance criteria (neither pane collapses to zero) but left specific pixel values unspecified | Conservative default: prevent zero-width panes without prescribing specific implementation values |
