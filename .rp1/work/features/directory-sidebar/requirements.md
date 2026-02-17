# Requirements Specification: Directory Sidebar Navigation

**Feature ID**: directory-sidebar
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-16

## 1. Feature Overview

When mkdn is invoked on a folder path (e.g., `mkdn ~/docs/`), the application displays a read-only sidebar panel listing the directory tree of Markdown files, allowing the user to click and navigate between documents within a single window. The sidebar serves as a navigation aid -- not a file manager -- and follows Solarized theming with visual separation from the main content area. This feature extends mkdn from a single-file viewer into a multi-file navigation experience for folder-based Markdown collections.

## 2. Business Context

### 2.1 Problem Statement

Developers working with LLM-generated documentation often produce collections of Markdown files organized in folder hierarchies (project specs, design docs, knowledge bases). Currently, mkdn requires opening each file individually from the terminal, creating a separate window per file. There is no way to browse and navigate between related documents within a single workspace, forcing users to repeatedly switch between terminal and mkdn windows or open many separate windows.

### 2.2 Business Value

- Reduces friction when reviewing multi-file Markdown collections produced by coding agents
- Keeps users within mkdn instead of switching to heavyweight editors for folder browsing
- Supports the daily-driver success criterion by handling a common real-world usage pattern (folder of docs)
- Maintains the "open, render beautifully, read, close" philosophy while extending it to "open folder, browse beautifully, read many, close"

### 2.3 Success Metrics

- SM-1: A user can invoke `mkdn ~/docs/` and immediately see all Markdown files in the directory tree
- SM-2: A user can navigate between files in the sidebar without returning to the terminal
- SM-3: The sidebar follows Solarized theming and feels visually integrated with the main content area
- SM-4: New or deleted Markdown files appear/disappear in the sidebar without restarting the app
- SM-5: The sidebar does not interfere with existing single-file usage (`mkdn file.md` behaves identically to today)

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Terminal Developer | Primary user. Invokes mkdn from CLI on folders of Markdown docs. Values speed and keyboard navigation. | Primary actor for all requirements |
| Documentation Reviewer | Reads through multi-file documentation sets (specs, ADRs, knowledge bases). Wants to browse sequentially. | Primary consumer of sidebar navigation |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project Owner | Extend daily-driver utility to folder-based workflows without compromising single-file simplicity |
| End Users | Quick, beautiful folder browsing that respects terminal-centric aesthetics |

## 4. Scope Definition

### 4.1 In Scope

- Sidebar panel displaying a tree of Markdown files when invoked on a directory
- Recursive directory scanning filtered to Markdown files (.md, .markdown) only
- Click-to-navigate: selecting a file in the sidebar loads it in the content area
- Keyboard shortcut to toggle sidebar visibility (Cmd+Shift+L)
- Resizable sidebar with draggable divider
- Directory watching for structural changes (file creation/deletion) at root and first-level subdirectories
- Solarized-themed sidebar with visual separation from content
- Welcome screen adaptation for directory mode
- Empty directory handling with informative message
- Depth-limited scanning with truncation indicator
- First-level directories expanded by default

### 4.2 Out of Scope

- File management operations (rename, delete, move, create) -- sidebar is read-only navigation only
- Drag-and-drop file reordering within the sidebar
- Multi-file selection or bulk operations
- Search/filter within the sidebar tree
- File previews on hover
- Bookmark or favorites functionality
- Watching for changes deeper than first-level subdirectories (v1 limitation)
- Opening multiple directories in a single sidebar
- Tab-based navigation between open files

### 4.3 Assumptions

- AS-1: The existing WelcomeView component can be adapted or extended for directory-mode messaging
- AS-2: The existing Solarized theme palette (backgroundSecondary) provides sufficient visual distinction for the sidebar background
- AS-3: Users primarily work with folder structures of moderate size (tens to low hundreds of Markdown files, not thousands)
- AS-4: The existing FileWatcher DispatchSource pattern can be adapted for directory-level watching
- AS-5: The existing CLI argument parsing can be extended to accept directory paths alongside file paths

## 5. Functional Requirements

### FR-1: Directory Invocation (Must Have)

**Actor**: Terminal Developer
**Action**: Invoke mkdn with a directory path argument
**Outcome**: A window opens showing the sidebar with the directory's Markdown file tree and a welcome screen in the content area
**Rationale**: Entry point for the folder browsing workflow; must feel as natural as opening a single file
**Acceptance Criteria**:
- AC-1.1: `mkdn ~/docs/` opens a window with the sidebar visible and the content area showing the directory-mode welcome message
- AC-1.2: `mkdn ./relative/path/` resolves relative paths correctly
- AC-1.3: `mkdn /nonexistent/path/` produces a meaningful error message and exits with a non-zero code
- AC-1.4: `mkdn ~/docs/` where the directory exists but the path has a trailing slash works identically to without

### FR-2: Single-File Behavior Preserved (Must Have)

**Actor**: Terminal Developer
**Action**: Invoke mkdn with a file path argument (existing behavior)
**Outcome**: The file opens in a window with no sidebar, identical to current behavior
**Rationale**: The directory sidebar must not regress or alter the single-file experience
**Acceptance Criteria**:
- AC-2.1: `mkdn file.md` opens a window with no sidebar panel visible
- AC-2.2: No sidebar toggle shortcut appears or functions when no directory is associated with the window

### FR-3: Mixed Arguments (Must Have)

**Actor**: Terminal Developer
**Action**: Invoke mkdn with both file and directory arguments (e.g., `mkdn file.md ~/docs/`)
**Outcome**: Separate windows open: the directory gets a sidebar window, the file gets a standard no-sidebar window
**Rationale**: Users may want to open a specific file alongside a folder; each should behave according to its type
**Acceptance Criteria**:
- AC-3.1: `mkdn file.md ~/docs/` opens two windows -- one with sidebar for the directory, one without sidebar for the file
- AC-3.2: Each window operates independently (closing one does not affect the other)

### FR-4: Markdown-Only File Tree (Must Have)

**Actor**: Documentation Reviewer
**Action**: View the sidebar file tree
**Outcome**: Only Markdown files (.md, .markdown) and directories containing them are displayed; all other file types are hidden
**Rationale**: Reduces visual noise and keeps focus on the relevant content
**Acceptance Criteria**:
- AC-4.1: Files with extensions other than .md and .markdown do not appear in the sidebar
- AC-4.2: Directories that contain no Markdown files (at any depth within the recursion limit) do not appear in the sidebar
- AC-4.3: Hidden files and directories (names starting with `.`) do not appear in the sidebar
- AC-4.4: The tree is sorted with directories first, then files, alphabetically within each group

### FR-5: File Navigation (Must Have)

**Actor**: Documentation Reviewer
**Action**: Click a Markdown file in the sidebar tree
**Outcome**: The file's content loads in the main content area (viewer), and the clicked file is visually highlighted as selected in the sidebar
**Rationale**: Core navigation interaction; must feel immediate and clear
**Acceptance Criteria**:
- AC-5.1: Clicking a file name in the sidebar loads and renders the file in the content area
- AC-5.2: The selected file row displays an accent-color background highlight (Finder sidebar style)
- AC-5.3: Only one file can be selected at a time; selecting a new file deselects the previous one
- AC-5.4: The content area transitions from the welcome view to the file content on first selection

### FR-6: Directory Expand/Collapse (Must Have)

**Actor**: Documentation Reviewer
**Action**: Click a directory entry or its disclosure indicator in the sidebar tree
**Outcome**: The directory expands to show its children, or collapses to hide them
**Rationale**: Standard tree navigation behavior; allows users to manage visual complexity
**Acceptance Criteria**:
- AC-6.1: Clicking a directory row toggles its expanded/collapsed state
- AC-6.2: A disclosure chevron indicates whether a directory is expanded or collapsed
- AC-6.3: First-level directories (direct children of the root) are expanded by default on initial load
- AC-6.4: Directories deeper than first level are collapsed by default
- AC-6.5: Expansion state is preserved when the tree refreshes due to file system changes

### FR-7: Sidebar Toggle (Must Have)

**Actor**: Terminal Developer
**Action**: Press Cmd+Shift+L or select the menu item
**Outcome**: The sidebar panel hides or shows with an animated transition
**Rationale**: Allows maximizing content area when sidebar is not needed; standard keyboard shortcut pattern
**Acceptance Criteria**:
- AC-7.1: Cmd+Shift+L toggles sidebar visibility when a directory is associated with the window
- AC-7.2: A "Toggle Sidebar" menu item exists in the View menu with the Cmd+Shift+L shortcut displayed
- AC-7.3: The menu item is disabled when the current window has no associated directory
- AC-7.4: The sidebar show/hide transition is animated (follows the project's animation pattern conventions)
- AC-7.5: The content area resizes to fill the available space when the sidebar is hidden

### FR-8: Resizable Sidebar (Should Have)

**Actor**: Documentation Reviewer
**Action**: Drag the divider between the sidebar and content area
**Outcome**: The sidebar width changes, constrained within minimum and maximum bounds
**Rationale**: Users have different preferences for sidebar width depending on file name lengths and screen size
**Acceptance Criteria**:
- AC-8.1: A draggable divider exists between the sidebar and content area
- AC-8.2: The sidebar has a minimum width constraint (prevents collapsing to unusably narrow)
- AC-8.3: The sidebar has a maximum width constraint (prevents consuming too much content space)
- AC-8.4: The divider provides a visible affordance (1pt border line using theme border color)
- AC-8.5: The cursor changes to a resize cursor when hovering over the divider

### FR-9: Directory-Mode Welcome View (Must Have)

**Actor**: Documentation Reviewer
**Action**: Open a directory before selecting any file
**Outcome**: The content area displays a welcome message appropriate to directory mode, e.g., "Select a file from the sidebar to begin reading"
**Rationale**: Provides clear guidance on what to do next; avoids a blank or confusing initial state
**Acceptance Criteria**:
- AC-9.1: When a directory is opened and no file is selected, the content area shows a directory-specific welcome message
- AC-9.2: The message text differs from the standard single-file welcome view (not "Open a Markdown file to get started")
- AC-9.3: The welcome message follows Solarized theming
- AC-9.4: The welcome view transitions to file content when the user selects a file from the sidebar

### FR-10: Directory Watching (Should Have)

**Actor**: Documentation Reviewer
**Action**: A Markdown file is added to or deleted from the watched directory (root or first-level subdirectories)
**Outcome**: The sidebar tree updates to reflect the change without manual intervention
**Rationale**: Keeps the sidebar accurate when working alongside tools that generate or modify Markdown files
**Acceptance Criteria**:
- AC-10.1: A new .md file created in the root directory appears in the sidebar tree
- AC-10.2: A .md file deleted from the root directory disappears from the sidebar tree
- AC-10.3: A new .md file created in a first-level subdirectory appears in the sidebar tree
- AC-10.4: A .md file deleted from a first-level subdirectory disappears from the sidebar tree
- AC-10.5: Changes deeper than first-level subdirectories are not detected (v1 known limitation)
- AC-10.6: The currently selected file remains selected after a tree refresh (unless it was deleted)
- AC-10.7: Directory expansion state is preserved across tree refreshes

### FR-11: Depth-Limited Scanning with Truncation Indicator (Should Have)

**Actor**: Documentation Reviewer
**Action**: Open a directory with deeply nested subdirectories
**Outcome**: The tree displays up to a defined depth limit, with a visual indicator where deeper content exists but is not shown
**Rationale**: Prevents performance degradation and visual overwhelm with deeply nested structures
**Acceptance Criteria**:
- AC-11.1: Directory scanning stops at a defined maximum depth (approximately 10 levels)
- AC-11.2: When a directory at the depth limit has children, a truncation indicator is shown (e.g., "..." or "N more items")
- AC-11.3: The truncation indicator is not clickable/interactive

### FR-12: Empty Directory Handling (Must Have)

**Actor**: Terminal Developer
**Action**: Invoke mkdn on a directory containing no Markdown files
**Outcome**: The sidebar panel displays with an empty-state message ("No Markdown files found"), and the content area shows the welcome view
**Rationale**: Provides clear feedback rather than a confusing empty sidebar
**Acceptance Criteria**:
- AC-12.1: The sidebar panel is visible (not hidden) when the directory contains no Markdown files
- AC-12.2: The sidebar displays an informative message such as "No Markdown files found"
- AC-12.3: The content area shows the directory-mode welcome view
- AC-12.4: If a Markdown file is subsequently added to the directory, it appears in the sidebar via directory watching

### FR-13: Solarized Sidebar Theming (Must Have)

**Actor**: Documentation Reviewer
**Action**: View and interact with the sidebar in either Solarized theme
**Outcome**: The sidebar follows the active Solarized theme and is visually distinct from the content area
**Rationale**: Consistent theming is a core differentiator of mkdn; the sidebar must not break the visual experience
**Acceptance Criteria**:
- AC-13.1: The sidebar background uses the theme's backgroundSecondary (or a dedicated sidebarBackground) color
- AC-13.2: Sidebar text uses the theme's foreground colors
- AC-13.3: The selection highlight uses the theme's accent color
- AC-13.4: When the user cycles themes (Cmd+T), the sidebar updates to the new theme immediately
- AC-13.5: The sidebar divider uses the theme's border color

### FR-14: Tree Row Visual Design (Should Have)

**Actor**: Documentation Reviewer
**Action**: View the sidebar file tree entries
**Outcome**: Each row shows appropriate indentation, icons, and typography for its type (file vs. directory)
**Rationale**: Visual clarity in the tree structure helps users navigate quickly
**Acceptance Criteria**:
- AC-14.1: Directory rows display a folder icon and a disclosure chevron
- AC-14.2: File rows display a document icon
- AC-14.3: Rows are indented by depth level to convey hierarchy
- AC-14.4: Row typography uses the theme's standard text styles
- AC-14.5: The sidebar header displays the root directory name

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

- NFR-1: Initial directory scan for a folder with up to 500 Markdown files should complete in under 1 second on a modern Mac
- NFR-2: Sidebar tree rendering should not cause visible frame drops during scrolling
- NFR-3: File navigation (click to load) should feel immediate; the sidebar selection highlight updates within one frame
- NFR-4: Directory watching should not consume noticeable CPU when idle

### 6.2 Security Requirements

- NFR-5: The sidebar only reads and displays file names and directory structure; it does not read file contents for previewing
- NFR-6: The sidebar respects macOS sandboxing and file access permissions (if applicable)

### 6.3 Usability Requirements

- NFR-7: The sidebar is keyboard-navigable as a future enhancement; v1 requires only mouse/trackpad interaction
- NFR-8: The sidebar toggle (Cmd+Shift+L) is discoverable via the menu bar
- NFR-9: The divider between sidebar and content is easy to grab (adequate hit target)

### 6.4 Compliance Requirements

- NFR-10: The sidebar respects the system Reduce Motion preference for all animations (show/hide transitions)
- NFR-11: The sidebar follows the project's existing animation pattern conventions (named primitives from AnimationConstants, MotionPreference resolution)

## 7. User Stories

### STORY-1: Open Folder from Terminal

**As a** Terminal Developer
**I want to** run `mkdn ~/docs/` from the terminal
**So that** I can browse all Markdown files in that folder within a single mkdn window

**Acceptance Scenarios**:

GIVEN a directory `~/docs/` containing Markdown files
WHEN the user runs `mkdn ~/docs/`
THEN a window opens with the sidebar showing the directory tree and the content area showing the directory-mode welcome message

GIVEN a directory `~/docs/` containing Markdown files and subdirectories
WHEN the window opens
THEN first-level subdirectories are expanded by default and deeper directories are collapsed

### STORY-2: Navigate Between Files

**As a** Documentation Reviewer
**I want to** click file names in the sidebar to view their content
**So that** I can read through a collection of documents without returning to the terminal

**Acceptance Scenarios**:

GIVEN the sidebar is showing a directory tree with multiple Markdown files
WHEN the user clicks a file name
THEN the file content loads in the content area and the file row is highlighted with the accent color

GIVEN a file is currently selected and displayed
WHEN the user clicks a different file
THEN the new file loads, the new row is highlighted, and the previous row's highlight is removed

### STORY-3: Manage Tree Visibility

**As a** Terminal Developer
**I want to** expand, collapse, and toggle the sidebar
**So that** I can control how much screen space the sidebar uses

**Acceptance Scenarios**:

GIVEN the sidebar is visible
WHEN the user presses Cmd+Shift+L
THEN the sidebar hides with an animated transition and the content area expands to fill the space

GIVEN a directory has subdirectories
WHEN the user clicks a directory row
THEN the directory toggles between expanded and collapsed states

### STORY-4: Resize Sidebar

**As a** Documentation Reviewer
**I want to** drag the sidebar divider to adjust its width
**So that** I can accommodate long file names or maximize content space

**Acceptance Scenarios**:

GIVEN the sidebar is visible
WHEN the user drags the divider between the sidebar and content area
THEN the sidebar width changes within the defined min/max constraints

### STORY-5: File System Changes Reflected

**As a** Documentation Reviewer
**I want to** see new Markdown files appear in the sidebar automatically
**So that** I do not need to restart mkdn when files are added or removed by other tools

**Acceptance Scenarios**:

GIVEN the sidebar is showing a directory tree
WHEN a new .md file is created in the root directory or a first-level subdirectory
THEN the file appears in the sidebar tree without user intervention

GIVEN a file is selected in the sidebar
WHEN that file is deleted from disk
THEN the file disappears from the sidebar and the content area returns to the welcome view

### STORY-6: Empty Folder Experience

**As a** Terminal Developer
**I want to** see clear feedback when I open a folder with no Markdown files
**So that** I understand the folder is valid but contains no viewable content

**Acceptance Scenarios**:

GIVEN a directory `~/empty/` containing no Markdown files
WHEN the user runs `mkdn ~/empty/`
THEN the sidebar shows "No Markdown files found" and the content area shows the directory-mode welcome view

GIVEN a previously empty directory
WHEN a .md file is added to the directory
THEN the sidebar updates to show the new file (replacing the empty-state message)

### STORY-7: Theme Consistency

**As a** Documentation Reviewer
**I want to** see the sidebar follow the same Solarized theme as the content area
**So that** the visual experience is cohesive

**Acceptance Scenarios**:

GIVEN the sidebar is visible in Solarized Dark
WHEN the user cycles the theme with Cmd+T
THEN the sidebar background, text, icons, and selection highlight all update to Solarized Light (and vice versa)

## 8. Business Rules

- BR-1: The sidebar is read-only navigation only. No file management operations (create, rename, delete, move) are provided through the sidebar.
- BR-2: Only files with .md or .markdown extensions are shown. All other file types are filtered out.
- BR-3: Hidden files and directories (names starting with `.`) are excluded from the tree.
- BR-4: Directories that contain no Markdown files (recursively, within the depth limit) are excluded from the tree.
- BR-5: The sidebar is only shown when mkdn is invoked on a directory. Single-file invocations never show a sidebar.
- BR-6: First-level directories are expanded by default; all deeper directories are collapsed by default.
- BR-7: The sidebar panel uses backgroundSecondary (or dedicated sidebar) color for visual separation from the main content area's background color.
- BR-8: Sort order within the tree: directories first, then files, alphabetically within each group (case-insensitive).

## 9. Dependencies & Constraints

- DEP-1: Depends on existing Solarized theme infrastructure (ThemeColors, SolarizedDark, SolarizedLight, PrintPalette) for sidebar theming
- DEP-2: Depends on existing CLI argument parsing (swift-argument-parser, FileValidator, LaunchContext) for directory path handling
- DEP-3: Depends on existing FileWatcher DispatchSource pattern for directory watching implementation
- DEP-4: Depends on existing DocumentState for file loading when a sidebar file is selected
- DEP-5: Depends on existing AnimationConstants and MotionPreference for sidebar show/hide animation
- CON-1: Directory watching is limited to root and first-level subdirectories in v1 (deeper changes require manual rescan or future enhancement)
- CON-2: Directory scanning depth is capped at approximately 10 levels to prevent performance degradation
- CON-3: The sidebar uses a custom HStack-based layout (not NavigationSplitView) to maintain consistency with the existing hidden-title-bar window chrome approach
- CON-4: Charter scope note -- the project charter's "Won't Do" list includes "File management or file browser UI." This feature is scoped as a read-only navigation aid (BR-1), which distinguishes it from file management. The charter's intent to exclude file management operations (CRUD) remains honored.

## 10. Clarifications Log

| # | Question | Answer | Source |
|---|----------|--------|--------|
| 1 | Charter says "Won't Do: File management or file browser UI" -- how to reconcile? | Scope sidebar as read-only navigation aid (no rename/delete/move/create). Distinguishes from "file management." | User clarification |
| 2 | Mixed file + directory arguments behavior? | Separate windows -- directory gets sidebar window, file gets no-sidebar window, independent. | User clarification |
| 3 | Welcome view in directory mode? | Different message: "Select a file from the sidebar to begin reading" | User clarification |
| 4 | Deep directory handling at depth cap? | Show truncation indicator when depth limit is reached | User clarification |
| 5 | Sidebar width fixed or resizable? | Resizable with draggable divider, min/max constraints | User clarification |
| 6 | File selection highlight style? | Accent color background on the row (Finder sidebar style) | User clarification |
| 7 | Empty directory invocation? | Show sidebar with "No Markdown files found" message + welcome view in content area | User clarification |
| 8 | Directory watcher scope? | Top-level only for v1 -- root and first-level subdirectory additions/deletions | User clarification |
