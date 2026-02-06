# PRD: Split-Screen Editor

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

The Split-Screen Editor surface provides a side-by-side Markdown editing experience within mkdn. It uses an `HSplitView` with a Markdown text editor on the left and a live-rendered preview on the right. Users toggle between two modes via a `ViewMode` picker in the toolbar:

- **Preview-only mode** -- reading mode, full-width rendered Markdown
- **Side-by-side mode** -- editor on the left, live preview on the right

The surface targets developers who produce Markdown artifacts with LLMs and coding agents and need to quickly view and make edits without leaving their terminal-centric workflow.

**Existing scaffolding**: `SplitEditorView`, `MarkdownEditorView`, `EditorViewModel`, `ViewMode` enum, `ViewModePicker`.

## Scope

### In Scope
- `HSplitView` with resizable divider (editor left, preview right)
- `ViewMode` toggle between preview-only and side-by-side via toolbar picker
- Plain-text Markdown editing with monospaced font and theme-consistent colors
- Live preview updates as the user types (editor text drives preview re-render)
- File load/save (Cmd+S) with unsaved-changes tracking
- Theme-aware editor pane (Solarized Dark/Light background and foreground)
- Integration with existing file-change detection (outdated indicator still works in edit mode)
- Polished animations and transitions per charter Design Philosophy

### Out of Scope
- Syntax highlighting within the editor pane
- Synchronized scroll position between editor and preview
- Line numbers or gutter in the editor pane
- Multiple file tabs or additional split panes
- Auto-save or timed save
- Markdown formatting toolbar (bold/italic/link buttons)
- Vim/Emacs keybinding modes

## Requirements

### Functional Requirements

1. **ViewMode toggle** -- Toolbar picker switches between `.preview` (full-width rendered Markdown) and `.sideBySide` (HSplitView with editor + preview). Default mode is `.preview`.
2. **HSplitView layout** -- In side-by-side mode, editor pane on the left, preview pane on the right, with a user-resizable divider. Default split ratio: 50/50.
3. **Plain-text editor** -- Monospaced font, theme-consistent foreground/background colors. Standard macOS text editing (undo/redo, cut/copy/paste, selection).
4. **Live preview** -- Preview pane re-renders as the user types. Editor text is the source of truth; changes flow through the existing MarkdownRenderer pipeline.
5. **File load** -- Opening a file (CLI, drag-drop, open dialog) populates both the editor text and the preview.
6. **File save (Cmd+S)** -- Writes editor text back to disk. Clears the unsaved-changes indicator.
7. **Unsaved-changes tracking** -- Visual indicator when editor text diverges from last-saved content.
8. **File-change detection in edit mode** -- The existing FileWatcher/OutdatedIndicator continues to function. If the file changes on disk while editing, the outdated indicator appears. User manually decides whether to reload (which would replace editor text).
9. **Theme-aware editor pane** -- Editor background and foreground colors sourced from the active Solarized theme (Dark or Light), matching the preview pane.

### Design Requirements (Charter: Design Philosophy)

Every visual and interactive element must be crafted with obsessive attention to sensory detail.

1. **Mode transition animation** -- Toggling between preview-only and side-by-side must animate smoothly. The editor pane slides in/out with a natural, physical-feeling transition -- not a jarring swap. Use `withAnimation(.spring(...))` or equivalent for organic motion.
2. **Divider interaction** -- The resizable divider should feel polished: smooth drag response, snap points at sensible ratios (e.g., 30/70, 50/50, 70/30), visual feedback on hover (subtle highlight or width change).
3. **Unsaved indicator animation** -- The unsaved-changes indicator uses a subtle, breathing animation timed to human rhythms (~12 cycles/min per charter) rather than a static dot. Gentle pulse that draws attention without being distracting.
4. **Outdated indicator** -- The file-change indicator in edit mode follows the same sensory design standard as the viewer mode indicator. Consistent animation language across the app.
5. **Focus transitions** -- Moving focus between editor and preview panes should feel natural with smooth visual feedback. No harsh focus rings; use theme-consistent subtle indicators.

### Non-Functional Requirements

1. **Responsiveness** -- Live preview updates should feel instant for typical Markdown files. Debounce re-rendering if needed to avoid jank during fast typing.
2. **Memory** -- No unbounded caching of rendered output; only the current document's rendered state is held.
3. **Accessibility** -- Standard macOS accessibility: VoiceOver support for the editor (native TextEditor provides this), keyboard-navigable mode toggle.
4. **Platform** -- macOS 14.0+ (Sonoma). Swift 6, SwiftUI, no WKWebView.

## Dependencies & Constraints

### Internal Dependencies
- **AppState** -- `@Observable` central state, file loading/saving
- **MarkdownRenderer** -- existing pipeline for parsing + rendering Markdown to SwiftUI views
- **FileWatcher** -- file-change detection for the outdated indicator
- **Theme system** -- Solarized Dark/Light colors for editor pane

### External Dependencies (SPM)
- **apple/swift-markdown** -- Markdown parsing (already in use for preview)
- No new external dependencies needed

### Constraints
- SwiftUI `TextEditor` is the editor component (limited styling control compared to NSTextView)
- `@main` SwiftUI App pattern with `@Observable` state
- Two-target layout: all editor code in `mkdnLib`

## Milestones

### Phase 1: ViewMode Toggle + HSplitView
- Wire up the `ViewMode` picker in the toolbar
- Implement `HSplitView` layout with resizable divider
- Toggle between preview-only and side-by-side modes
- **Mode transition animation** -- smooth slide-in/out of editor pane

### Phase 2: Editor Pane
- Plain-text `TextEditor` with monospaced font
- Theme-aware foreground/background colors (Solarized)
- Standard macOS editing (undo/redo, cut/copy/paste)
- Wire editor text as source of truth for live preview re-rendering
- **Divider polish** -- smooth drag, snap points, hover feedback

### Phase 3: File I/O + Unsaved Tracking
- Cmd+S save functionality
- **Unsaved-changes indicator** with breathing animation (~12 cycles/min)
- File load populating both editor text and preview
- **Focus transitions** -- natural feel moving between panes

### Phase 4: File-Change Detection + Polish
- Outdated indicator in edit mode (matching viewer mode design standard)
- Reload flow when file changes on disk while editing
- Debounced preview updates for responsiveness during fast typing
- Final animation and interaction polish pass

## Open Questions

- SwiftUI `TextEditor` vs `NSTextView` via `NSViewRepresentable`: TextEditor has limited styling control. If theme-consistent styling proves insufficient, may need to drop to NSTextView.
- Optimal debounce interval for live preview re-rendering during fast typing (100ms? 250ms? Adaptive?)
- Whether the mode transition animation should preserve scroll position in the preview when toggling

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | SwiftUI `TextEditor` provides sufficient styling for theme-consistent editor | May need `NSViewRepresentable` wrapping `NSTextView` for full control | Will Do: Split-screen toggle |
| A2 | Live preview re-rendering is fast enough with debouncing | Large documents may need incremental rendering or virtualization | Will Do: Split-screen edit+preview |
| A3 | `HSplitView` provides smooth, polished divider interaction | May need custom divider view for snap points and hover feedback | Design Philosophy: obsessive detail |
| A4 | Breathing animation at ~12 cycles/min is achievable with SwiftUI animations | May need CADisplayLink or custom timing for precise rhythm | Design Philosophy: human rhythms |
| A5 | File-change detection and editor state coexist without conflicts | Reload-while-editing needs careful UX to avoid data loss | Will Do: File-change detection |
