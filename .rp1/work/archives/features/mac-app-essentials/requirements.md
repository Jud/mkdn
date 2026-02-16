# Requirements Specification: Mac App Essentials

**Feature ID**: mac-app-essentials
**Parent PRD**: Cross-cutting (references [controls](../../prds/controls.md), [cli-launch](../../prds/cli-launch.md), [core-markdown-rendering](../../prds/core-markdown-rendering.md))
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-13

## 1. Feature Overview

Eight standard macOS application features that every polished Mac app needs, implemented to the quality bar established by the project charter: elegance, performance, and obsessive attention to sensory detail. These are well-understood, mechanical features -- Find in Document, Print, Zoom, Save As, Code Block Copy Button, Task List Checkboxes, Multiple File CLI Opening, and About Window -- unified by the expectation that each must feel native, minimal, and considered.

## 2. Business Context

### 2.1 Problem Statement

mkdn currently lacks several standard macOS application capabilities that developers expect from any daily-driver tool. Users cannot search within documents, print them, adjust text size, save copies, copy code blocks without manual selection, see task list checkboxes rendered visually, open multiple files from the CLI in one invocation, or view app version information. Each missing feature is a friction point that erodes the "open, render beautifully, edit, close" workflow.

### 2.2 Business Value

These features collectively raise mkdn from a capable viewer to a complete Mac application. Each individually removes a paper cut; together they eliminate the class of moments where a developer thinks "I need to switch to another tool for this." The charter's success criterion -- personal daily-driver use -- requires that these standard capabilities are present and polished.

### 2.3 Success Metrics

| Metric | Target |
|--------|--------|
| All eight features functional on macOS 14+ | 100% |
| Zero new SwiftLint violations introduced | 0 |
| Each feature accessible via standard macOS keyboard shortcut or interaction pattern | 100% |
| No perceptible lag (>50ms) from any keyboard shortcut activation | 0 violations |
| Zoom preference persists across app restarts | Verified |
| Multiple files from CLI each open in their own window | Verified for 1-10 files |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevant Features |
|-----------|-------------|-------------------|
| Terminal Developer | Primary user. Works from CLI, opens Markdown files via `mkdn` command. Values keyboard shortcuts and zero-friction workflows. | All eight features |
| Document Reviewer | Reads long Markdown documents, needs to search for content and print for offline review. | Find in Document, Print, Zoom |
| Code Consumer | Reviews Markdown containing code blocks (LLM-generated artifacts, documentation). Needs to extract code quickly. | Code Block Copy Button |
| Multi-Document User | Works with multiple related Markdown files simultaneously (e.g., PRDs, specs, meeting notes). | Multiple File CLI Opening, Save As |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project Creator | Daily-driver completeness. Every expected Mac app feature present and polished. |
| Future Users | Standard macOS behavior. Features work exactly as expected from other Mac apps. |

## 4. Scope Definition

### 4.1 In Scope

- **Find in Document**: NSTextView built-in find bar via `performFindPanelAction`. Find, Find Next (Cmd+G), Find Previous (Shift+Cmd+G), Use Selection for Find (Cmd+E) in Edit menu.
- **Print**: NSTextView built-in print support. Print... (Cmd+P) and Page Setup... in File menu. Printed output uses the current theme's colors.
- **Zoom In/Out**: Persisted scale factor in AppSettings. Scaling applied to preview text rendering in SelectableTextView. Zoom In (Cmd+Plus), Zoom Out (Cmd+Minus), Actual Size (Cmd+0) in View menu.
- **Save As**: NSSavePanel to save current content to a new file location. DocumentState updated to track the new URL. Save As... (Shift+Cmd+S) in File menu.
- **Code Block Copy Button**: Hover-revealed copy button on code blocks. Copies code content (excluding the language label) to the system clipboard. Theme-aware appearance.
- **Task List Checkbox Rendering**: Visual rendering of `- [ ]` as unchecked and `- [x]` as checked checkboxes in the Markdown preview. Read-only (non-interactive). Uses SF Symbols or native checkbox appearance.
- **Multiple File CLI Opening**: CLIHandler/ArgumentParser updated to accept multiple file arguments. Each file opens in its own window via FileOpenCoordinator. Independent validation per file.
- **About Window**: Standard macOS About panel via `NSApp.orderFrontStandardAboutPanel` with customization, or a clean custom SwiftUI window. Shows app icon, app name, version string. Minimal and elegant.

### 4.2 Out of Scope

- Find and Replace (editing is side-by-side mode only; find-and-replace is a future editor enhancement)
- Export to PDF/HTML (charter explicitly excludes export formats)
- Custom zoom levels beyond the standard increment/decrement pattern
- Interactive task list checkboxes (toggle state on click, write back to file)
- Glob pattern support for CLI file arguments (e.g., `mkdn *.md`)
- stdin piping (`cat file.md | mkdn`)
- Custom About window content beyond icon, name, and version (no credits, no license text unless trivially included by the standard panel)

### 4.3 Assumptions

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A-1 | NSTextView's built-in find bar works correctly with the TextKit 2 configuration used by SelectableTextView | May need to bridge to TextKit 1 find APIs or implement custom find UI |
| A-2 | NSTextView's built-in print support produces acceptable themed output without custom NSPrintOperation subclassing | May need a custom print formatter that applies theme colors to a print-specific attributed string |
| A-3 | Text scaling via NSTextView's textContainerInset or magnification produces clean, crisp text at non-1x factors | May need to adjust font sizes directly rather than relying on view-level scaling |
| A-4 | swift-markdown's `ListItem` exposes the checkbox property needed to distinguish `- [ ]` from `- [x]` | May need to inspect raw text or use a regex-based pre-parse step |
| A-5 | The `execv` re-launch pattern in `main.swift` can be extended to pass multiple file paths via environment variable | May need a different IPC mechanism (temp file, multiple env vars) for many files |
| A-6 | Code block copy button can be implemented as a SwiftUI overlay on the existing NSTextAttachment-based code block rendering | May need to add hover tracking at the NSTextView level and position the button manually |

## 5. Functional Requirements

### 5.1 Find in Document

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-FIND-001 | Must Have | Terminal Developer | User can invoke Find (Cmd+F) to reveal the system find bar in the preview pane | Standard Mac text search capability expected in any document viewer | GIVEN a document is open WHEN user presses Cmd+F THEN the NSTextView find bar appears at the top of the text view |
| REQ-FIND-002 | Must Have | Terminal Developer | User can navigate search results with Find Next (Cmd+G) and Find Previous (Shift+Cmd+G) | Sequential navigation through matches is the standard macOS find workflow | GIVEN the find bar is open with a search term that has multiple matches WHEN user presses Cmd+G THEN the selection moves to the next match; WHEN user presses Shift+Cmd+G THEN the selection moves to the previous match |
| REQ-FIND-003 | Should Have | Terminal Developer | User can populate the find bar with the current text selection via Use Selection for Find (Cmd+E) | Standard macOS text selection shortcut for find; reduces friction when searching for visible text | GIVEN text is selected in the preview pane WHEN user presses Cmd+E THEN the selected text populates the system find pasteboard and the find bar search field |
| REQ-FIND-004 | Must Have | Terminal Developer | Find, Find Next, Find Previous, and Use Selection for Find are available as menu items in the Edit menu | Menu bar serves as the discovery layer for keyboard shortcuts per the controls PRD | GIVEN the app is running WHEN user opens the Edit menu THEN Find..., Find Next, Find Previous, and Use Selection for Find are listed with their keyboard shortcuts |

### 5.2 Print

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-PRINT-001 | Must Have | Document Reviewer | User can print the current document via Cmd+P | Standard macOS document printing capability | GIVEN a document is open WHEN user presses Cmd+P THEN the macOS print dialog appears with the document content |
| REQ-PRINT-002 | Should Have | Document Reviewer | Printed output uses the current theme's color palette (syntax highlighting, backgrounds, foreground colors) | The printed artifact should reflect the same aesthetic the user sees on screen; the charter emphasizes visual consistency | GIVEN a document is open with Solarized Dark theme WHEN user prints THEN the printed output uses Solarized Dark colors for text, code blocks, and headings |
| REQ-PRINT-003 | Should Have | Document Reviewer | Page Setup... is available in the File menu | Standard macOS print workflow includes page setup for paper size and orientation | GIVEN the app is running WHEN user opens the File menu THEN Page Setup... is listed |
| REQ-PRINT-004 | Must Have | Document Reviewer | Print... is available in the File menu with Cmd+P shortcut | Menu bar discovery layer | GIVEN the app is running WHEN user opens the File menu THEN Print... is listed with Cmd+P shortcut |

### 5.3 Zoom In/Out

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-ZOOM-001 | Must Have | Terminal Developer | User can increase text size via Zoom In (Cmd+Plus) | Standard macOS zoom behavior for document readability | GIVEN a document is open WHEN user presses Cmd+Plus THEN the preview text renders at a larger scale factor |
| REQ-ZOOM-002 | Must Have | Terminal Developer | User can decrease text size via Zoom Out (Cmd+Minus) | Standard macOS zoom behavior for overview reading | GIVEN a document is open at a scale >1.0 WHEN user presses Cmd+Minus THEN the preview text renders at a smaller scale factor |
| REQ-ZOOM-003 | Must Have | Terminal Developer | User can reset to default size via Actual Size (Cmd+0) | Quick return to baseline after zooming in/out | GIVEN a document is open at a non-default scale WHEN user presses Cmd+0 THEN the scale resets to 1.0 |
| REQ-ZOOM-004 | Must Have | Terminal Developer | The zoom scale factor is persisted across app restarts | Users set their preferred reading size once; it should stick | GIVEN the user sets zoom to 1.5x and quits WHEN the app is relaunched THEN the zoom scale is 1.5x |
| REQ-ZOOM-005 | Must Have | Terminal Developer | Zoom In, Zoom Out, and Actual Size are available as menu items in the View menu | Menu bar discovery layer | GIVEN the app is running WHEN user opens the View menu THEN Zoom In, Zoom Out, and Actual Size are listed with their keyboard shortcuts |
| REQ-ZOOM-006 | Should Have | Terminal Developer | Zoom scaling produces crisp, sharp text at all supported scale factors | The charter demands visual quality; blurry or aliased text at zoom levels would violate the design philosophy | GIVEN a document is open WHEN user zooms to any supported scale factor THEN text remains sharp and legible with no visible pixelation |

### 5.4 Save As

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-SAVEAS-001 | Must Have | Multi-Document User | User can save the current document to a new file location via Save As (Shift+Cmd+S) | Standard file management capability for creating copies or saving to a different directory | GIVEN a document is open WHEN user presses Shift+Cmd+S THEN an NSSavePanel appears allowing them to choose a new file name and location |
| REQ-SAVEAS-002 | Must Have | Multi-Document User | After saving to a new location, DocumentState tracks the new file URL | The window should now represent the new file; subsequent Cmd+S saves should write to the new location | GIVEN the user completes Save As to a new path WHEN Save As completes successfully THEN DocumentState.currentFileURL reflects the new path AND the file watcher monitors the new path AND the window title reflects the new filename |
| REQ-SAVEAS-003 | Must Have | Multi-Document User | Save As... is available in the File menu with Shift+Cmd+S shortcut | Menu bar discovery layer | GIVEN the app is running WHEN user opens the File menu THEN Save As... is listed with Shift+Cmd+S shortcut |
| REQ-SAVEAS-004 | Should Have | Multi-Document User | Save As defaults the filename to the current document's name and the directory to the current document's directory | Reduces friction; user should not start from a blank save dialog | GIVEN a document "readme.md" is open from ~/Projects/ WHEN user invokes Save As THEN the save panel pre-fills "readme.md" as the filename and ~/Projects/ as the directory |

### 5.5 Code Block Copy Button

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-COPY-001 | Must Have | Code Consumer | A copy button appears when the user hovers over a code block | Code blocks in LLM-generated Markdown are frequently copied; hover-reveal keeps the UI clean per the controls PRD philosophy | GIVEN a document with code blocks is displayed WHEN the user hovers the mouse over a code block THEN a copy button becomes visible in the code block area |
| REQ-COPY-002 | Must Have | Code Consumer | Clicking the copy button copies the code block content (excluding the language label) to the system clipboard | The user wants the raw code, not the metadata | GIVEN the copy button is visible on a code block WHEN the user clicks the copy button THEN the code content (without language label, without leading/trailing whitespace) is placed on the system clipboard |
| REQ-COPY-003 | Should Have | Code Consumer | The copy button provides brief visual feedback on successful copy (e.g., checkmark icon, subtle animation) | Confirmation that the action completed; the charter's design philosophy demands that interactive elements provide feedback | GIVEN the user clicks the copy button WHEN the copy succeeds THEN the button briefly shows a success state (checkmark or similar) before reverting to the default icon |
| REQ-COPY-004 | Must Have | Code Consumer | The copy button is theme-aware (colors, opacity consistent with current theme) | Visual consistency per the theming system | GIVEN the app is using Solarized Dark theme WHEN a copy button appears on hover THEN its colors (icon, background) are consistent with the Solarized Dark palette |
| REQ-COPY-005 | Should Have | Code Consumer | The copy button appears and disappears with a subtle animation consistent with the app's motion design language | The charter's design philosophy applies to every interactive element; the button should not appear/disappear abruptly | GIVEN the user moves the mouse over a code block THEN the copy button fades in using quickFade or similar named animation primitive; WHEN the mouse leaves THEN the button fades out |

### 5.6 Task List Checkbox Rendering

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-TASK-001 | Must Have | Terminal Developer | `- [ ]` renders as a visually unchecked checkbox in the preview | Task lists are common in Markdown used with LLMs and coding agents; visual checkboxes are more scannable than raw syntax | GIVEN a document contains `- [ ] incomplete task` WHEN rendered in preview THEN an unchecked checkbox visual (empty square or circle) appears before the task text |
| REQ-TASK-002 | Must Have | Terminal Developer | `- [x]` renders as a visually checked checkbox in the preview | Visual completion status at a glance | GIVEN a document contains `- [x] completed task` WHEN rendered in preview THEN a checked checkbox visual (filled/checked square or checkmark) appears before the task text |
| REQ-TASK-003 | Must Have | Terminal Developer | Task list checkboxes are read-only (not interactive) | mkdn is primarily a viewer; interactive checkboxes would require file-write logic and are out of scope for this feature | GIVEN a rendered task list checkbox WHEN the user clicks it THEN nothing happens (no state change, no error) |
| REQ-TASK-004 | Should Have | Terminal Developer | Checkboxes use SF Symbols or native macOS checkbox appearance for a polished look | The charter demands native feel; custom-drawn checkboxes risk looking foreign | GIVEN task list items are rendered THEN the checkbox visuals use SF Symbols (e.g., square, checkmark.square.fill) or equivalent native macOS appearance |
| REQ-TASK-005 | Should Have | Terminal Developer | Checkbox color is theme-aware | Visual consistency with the rest of the rendered content | GIVEN the app is using Solarized Dark theme THEN checkbox icons use a foreground color from the Solarized Dark palette |

### 5.7 Multiple File CLI Opening

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-MULTI-001 | Must Have | Multi-Document User | User can open multiple files from the CLI: `mkdn file1.md file2.md file3.md` | Developers frequently need to view several related documents side by side | GIVEN the user runs `mkdn a.md b.md c.md` from the terminal THEN three separate windows open, each displaying one of the files |
| REQ-MULTI-002 | Must Have | Multi-Document User | Each file is validated independently (existence, extension) | One invalid file should not block the valid ones | GIVEN the user runs `mkdn a.md nonexistent.md b.md` THEN a.md and b.md open in windows AND an error is printed to stderr for nonexistent.md |
| REQ-MULTI-003 | Must Have | Multi-Document User | Each file opens in its own window via FileOpenCoordinator | Consistent with the existing multi-window architecture | GIVEN multiple valid files are provided WHEN the app launches THEN FileOpenCoordinator.pendingURLs contains all valid file URLs |
| REQ-MULTI-004 | Should Have | Multi-Document User | The ArgumentParser definition accepts a variadic file argument | Clean CLI interface; `mkdn --help` shows that multiple files are accepted | GIVEN the user runs `mkdn --help` THEN the usage shows that multiple file paths are accepted |

### 5.8 About Window

| REQ-ID | Priority | User Type | Requirement | Rationale | Acceptance Criteria |
|--------|----------|-----------|-------------|-----------|---------------------|
| REQ-ABOUT-001 | Must Have | Terminal Developer | An About menu item is accessible in the application menu | Standard macOS application convention | GIVEN the app is running WHEN user opens the application menu THEN "About mkdn" is listed |
| REQ-ABOUT-002 | Must Have | Terminal Developer | The About window displays the app icon, app name ("mkdn"), and version string | Standard information expected in any macOS About panel | GIVEN the user selects About mkdn THEN a window/panel appears showing the app icon, "mkdn" name, and the version number (e.g., "1.0.0") |
| REQ-ABOUT-003 | Should Have | Terminal Developer | The About window is minimal and elegant, consistent with the app's design language | The charter demands that no element is too small to get right; the About window should reflect the same care as the rest of the app | GIVEN the About window is displayed THEN it appears clean, minimal, and visually consistent with the app's theme or standard macOS styling |
| REQ-ABOUT-004 | Could Have | Terminal Developer | The About window uses `NSApp.orderFrontStandardAboutPanel` with appropriate customization keys | The standard macOS About panel provides familiar, native appearance with minimal code | GIVEN the About menu item is selected THEN the standard macOS About panel is presented, customized with mkdn's icon, name, and version |

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| NFR-ID | Requirement | Priority |
|--------|-------------|----------|
| NFR-PERF-001 | Find bar activation (Cmd+F) responds in under 50ms | Must Have |
| NFR-PERF-002 | Find Next/Previous navigation responds in under 50ms per match | Must Have |
| NFR-PERF-003 | Zoom In/Out re-renders at the new scale without visible flicker or lag on Apple Silicon | Must Have |
| NFR-PERF-004 | Print dialog appears within 500ms of Cmd+P | Should Have |
| NFR-PERF-005 | Code block copy button hover reveal has no perceptible delay (under 100ms) | Must Have |
| NFR-PERF-006 | Multiple file CLI opening: all windows appear within 2 seconds for up to 10 files | Should Have |

### 6.2 Security Requirements

| NFR-ID | Requirement | Priority |
|--------|-------------|----------|
| NFR-SEC-001 | Save As respects macOS sandbox and file permissions (if sandboxed in the future) | Should Have |
| NFR-SEC-002 | Clipboard operations use the standard NSPasteboard API with no custom pasteboard types | Must Have |

### 6.3 Usability Requirements

| NFR-ID | Requirement | Priority |
|--------|-------------|----------|
| NFR-UX-001 | All keyboard shortcuts follow macOS Human Interface Guidelines conventions | Must Have |
| NFR-UX-002 | All features are discoverable via the macOS menu bar | Must Have |
| NFR-UX-003 | Zoom level is displayed briefly via the existing ephemeral overlay mechanism (e.g., "125%") | Should Have |
| NFR-UX-004 | Code block copy button is visible enough to be discoverable but subtle enough not to distract from reading | Must Have |
| NFR-UX-005 | Task list checkboxes are visually distinct from regular list item bullets | Must Have |

### 6.4 Compliance Requirements

| NFR-ID | Requirement | Priority |
|--------|-------------|----------|
| NFR-COMPLY-001 | All new code passes SwiftLint strict mode | Must Have |
| NFR-COMPLY-002 | All new code uses SwiftFormat | Must Have |
| NFR-COMPLY-003 | No ObservableObject usage; all state via @Observable | Must Have |
| NFR-COMPLY-004 | No WKWebView usage for any feature in this set | Must Have |
| NFR-COMPLY-005 | All new observable state is @MainActor-isolated | Must Have |

## 7. User Stories

### STORY-FIND-001: Find text in document
**As a** Terminal Developer
**I want** to press Cmd+F and search for text in the rendered Markdown preview
**So that** I can quickly locate specific content in long documents

**Acceptance:**
- GIVEN a Markdown document is open in preview mode
- WHEN I press Cmd+F
- THEN the system find bar appears
- AND I can type a search term to highlight matches
- AND I can press Cmd+G to jump to the next match
- AND I can press Shift+Cmd+G to jump to the previous match

### STORY-PRINT-001: Print a document
**As a** Document Reviewer
**I want** to print the current document with its themed colors
**So that** I can review it offline with the same visual styling I see on screen

**Acceptance:**
- GIVEN a Markdown document is open with Solarized Dark theme
- WHEN I press Cmd+P
- THEN the macOS print dialog appears
- AND the print preview shows the document with Solarized Dark colors

### STORY-ZOOM-001: Adjust text size
**As a** Terminal Developer
**I want** to zoom in and out of the document preview
**So that** I can read comfortably at my preferred text size

**Acceptance:**
- GIVEN a Markdown document is open
- WHEN I press Cmd+Plus three times
- THEN the text is visibly larger
- AND WHEN I press Cmd+0
- THEN the text returns to default size
- AND WHEN I quit and relaunch
- THEN the zoom level I last set is remembered (if I did not reset)

### STORY-SAVEAS-001: Save a copy
**As a** Multi-Document User
**I want** to save the current document to a new file location
**So that** I can create a copy or reorganize my files without leaving mkdn

**Acceptance:**
- GIVEN a document "notes.md" is open from ~/Desktop/
- WHEN I press Shift+Cmd+S
- THEN an NSSavePanel appears with "notes.md" as the default filename
- AND WHEN I choose a new location and confirm
- THEN the file is saved to the new location
- AND the window title updates to reflect the new filename

### STORY-COPY-001: Copy code from a code block
**As a** Code Consumer
**I want** a copy button that appears when I hover over a code block
**So that** I can copy code to my clipboard with one click instead of manually selecting it

**Acceptance:**
- GIVEN a document contains a Swift code block
- WHEN I hover my mouse over the code block
- THEN a subtle copy button appears (e.g., top-right corner)
- AND WHEN I click the copy button
- THEN the code content (without language label) is on my clipboard
- AND the button briefly shows a checkmark to confirm the copy

### STORY-TASK-001: View task list progress
**As a** Terminal Developer
**I want** to see `- [ ]` and `- [x]` rendered as visual checkboxes
**So that** I can quickly scan task completion status in LLM-generated checklists

**Acceptance:**
- GIVEN a document contains `- [ ] todo` and `- [x] done`
- WHEN rendered in preview
- THEN "todo" has an empty checkbox icon before it
- AND "done" has a filled/checked checkbox icon before it
- AND clicking either checkbox does nothing

### STORY-MULTI-001: Open multiple files from terminal
**As a** Multi-Document User
**I want** to run `mkdn file1.md file2.md file3.md` and have all three open in separate windows
**So that** I can view multiple related documents simultaneously without running the command three times

**Acceptance:**
- GIVEN three valid Markdown files exist
- WHEN I run `mkdn a.md b.md c.md`
- THEN three windows open, each displaying one file
- AND if one file does not exist, the other two still open
- AND an error is printed to stderr for the missing file

### STORY-ABOUT-001: Check app version
**As a** Terminal Developer
**I want** to see the app version in an About window
**So that** I know which version I have installed when reporting issues or checking for updates

**Acceptance:**
- GIVEN the app is running
- WHEN I select "About mkdn" from the application menu
- THEN a panel appears showing the app icon, "mkdn", and the version number

## 8. Business Rules

| Rule ID | Rule | Applies To |
|---------|------|------------|
| BR-001 | Find operations use NSTextView's built-in find bar via `performFindPanelAction`; no custom find UI | Find in Document |
| BR-002 | Print uses NSTextView's built-in print support; no custom print rendering pipeline | Print |
| BR-003 | Zoom scale factor has a minimum of 0.5x and a maximum of 3.0x to prevent unusable extremes | Zoom In/Out |
| BR-004 | Zoom increments/decrements by 0.1 (10%) per step | Zoom In/Out |
| BR-005 | Default zoom scale factor is 1.0 | Zoom In/Out |
| BR-006 | Save As creates a new file; it does not modify the original file | Save As |
| BR-007 | After Save As, the window is associated with the new file (subsequent Cmd+S writes to new location, file watcher monitors new path) | Save As |
| BR-008 | Code block copy button copies the raw code string, not the rendered/attributed text and not the language label | Code Block Copy Button |
| BR-009 | Task list checkboxes are strictly visual (read-only); no write-back to the Markdown source | Task List Checkbox Rendering |
| BR-010 | When opening multiple files from CLI, validation errors for individual files are non-fatal; valid files still open | Multiple File CLI Opening |
| BR-011 | The About window uses the same version string as `mkdn --version` | About Window |

## 9. Dependencies & Constraints

### Internal Dependencies

| Component | File(s) | Impact |
|-----------|---------|--------|
| MkdnCommands | `mkdn/App/MkdnCommands.swift` | Add Edit menu (Find items), expand File menu (Print, Page Setup, Save As), expand View menu (Zoom items) |
| AppSettings | `mkdn/App/AppSettings.swift` | Add persisted `scaleFactor` property for zoom |
| DocumentState | `mkdn/App/DocumentState.swift` | Add `saveAs(to:)` method; update `currentFileURL` and file watcher on Save As |
| SelectableTextView | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | Wire up find bar actions; apply zoom scale factor to text rendering |
| CodeBlockView | `mkdn/Features/Viewer/Views/CodeBlockView.swift` | Add hover-triggered copy button overlay |
| MarkdownBlock | `mkdn/Core/Markdown/MarkdownBlock.swift` | Add `isChecked` field to `ListItem` for task list checkbox state |
| MarkdownVisitor | `mkdn/Core/Markdown/MarkdownVisitor.swift` | Extract checkbox state from `ListItem.checkbox` property in swift-markdown AST |
| MkdnCLI | `mkdn/Core/CLI/MkdnCLI.swift` | Change `file: String?` to `files: [String]` (variadic argument) |
| LaunchContext | `mkdn/Core/CLI/LaunchContext.swift` | Support multiple file URLs |
| FileOpenCoordinator | `mkdn/App/FileOpenCoordinator.swift` | Receives multiple URLs for window creation |
| main.swift | `mkdnEntry/main.swift` | Update CLI flow to handle multiple files and pass them to LaunchContext/FileOpenCoordinator |
| AppDelegate | `mkdn/App/AppDelegate.swift` | Wire About menu item (may already be handled by standard macOS menu) |

### External Dependencies

None. All eight features use built-in macOS/SwiftUI/AppKit APIs. No new SPM packages required.

### Constraints

- **macOS 14.0+**: All APIs must be available on Sonoma.
- **Swift 6 Strict Concurrency**: All state mutations through @MainActor-isolated types.
- **No WKWebView**: Absolute constraint from charter.
- **SwiftLint Strict Mode**: All new code must pass.
- **NSTextView Integration**: Find and Print features depend on NSTextView's built-in capabilities, which must work correctly with the TextKit 2 configuration in SelectableTextView.
- **Existing `execv` Pattern**: Multiple file CLI opening must work within or extend the existing `execv`-based re-launch pattern in `main.swift`, which was designed for single-file launch.

## 10. Clarifications Log

| # | Question | Resolution | Source |
|---|----------|------------|--------|
| 1 | Which user types interact with each feature? | Identified four user types: Terminal Developer (all), Document Reviewer (Find/Print/Zoom), Code Consumer (Copy), Multi-Document User (Multi-file/Save As) | Inferred from charter target users and feature descriptions |
| 2 | Should Find work in both preview-only and side-by-side modes? | Find should work in the preview pane (SelectableTextView) in both modes. The editor pane's TextEditor has its own find support natively. | Inferred from architecture: SelectableTextView is the NSTextView used in both modes |
| 3 | What zoom increment is appropriate? | 10% (0.1x) per step, matching common macOS app behavior (Safari, Preview) | Conservative default based on macOS conventions |
| 4 | What are reasonable zoom bounds? | 0.5x minimum, 3.0x maximum | Conservative default; prevents unusably small or large text |
| 5 | Should Save As support file types other than .md? | No. Save As saves as Markdown (.md) only, consistent with the app's single-format focus. | Inferred from charter scope (Markdown viewer/editor only) |
| 6 | How should the copy button interact with the existing code block overlay rendering? | Code blocks are rendered as overlay views (NSHostingView over NSTextAttachment). The copy button should be part of the CodeBlockView SwiftUI hierarchy. | Inferred from modules.md and CodeBlockView source |
| 7 | Does swift-markdown expose task list checkbox state? | swift-markdown's `ListItem` has a `checkbox` property of type `Checkbox?` with cases `.checked` and `.unchecked`. This is the recommended API. | Inferred from swift-markdown library documentation |
| 8 | How should multiple files be passed through the `execv` re-launch? | The `MKDN_LAUNCH_FILE` environment variable can be extended to contain multiple paths separated by a delimiter (e.g., newline), or multiple env vars can be used. Alternatively, FileOpenCoordinator can be populated before `MkdnApp.main()` for all paths. | Inferred from current main.swift architecture |
| 9 | Should the About window use the standard panel or a custom SwiftUI view? | Default to `NSApp.orderFrontStandardAboutPanel` with customization. Only build a custom view if the standard panel proves insufficient. | Conservative default per requirements text |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD association | Cross-cutting (controls, cli-launch, core-markdown-rendering) | No single PRD matches; feature bundle spans menu commands, CLI, and rendering. Referenced the three most relevant PRDs. |
| Zoom increment | 0.1x (10%) per step | Standard macOS convention (Safari, Preview, TextEdit behavior) |
| Zoom bounds | 0.5x to 3.0x | Conservative range covering accessibility needs without rendering extremes |
| Copy button position | Top-right corner of code block (hover-reveal) | Most common convention in code documentation viewers (GitHub, VS Code, etc.) |
| Task list checkbox style | SF Symbols (square, checkmark.square.fill) | Native macOS appearance; charter demands native feel |
| About window approach | NSApp.orderFrontStandardAboutPanel | Minimal code, native appearance, matches charter's "minimal and elegant" directive |
| Multiple file env passing | Extend MKDN_LAUNCH_FILE with newline-delimited paths | Simplest extension of existing pattern; avoids new IPC mechanisms |
| Save As file type | .md only | Charter scope is Markdown only; no export formats |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| "Subtle copy button" -- how subtle? | Fade-in on hover using quickFade animation primitive, 50% opacity idle state, theme-aware foreground secondary color | Animation patterns from patterns.md (quickFade, hover feedback modifiers); charter design philosophy |
| "Theme-aware" for copy button -- which colors? | Use `foregroundSecondary` for icon, `codeBackground` with slight opacity adjustment for button background | CodeBlockView already uses these color tokens; maintain visual consistency |
| "Elegant" About window -- what qualifies? | Standard macOS About panel with correct icon, app name, and version. No custom styling needed; the standard panel is inherently elegant. | Charter: "No element is too small to get right" -- but the standard macOS panel is the right choice for this element |
| "Native checkbox appearance" -- specific SF Symbol names? | `square` for unchecked, `checkmark.square.fill` for checked | Standard SF Symbol names for checkbox representation; widely used in macOS apps |
| "Current theme's colors" for print -- how to apply? | Use the existing NSAttributedString (which already has theme colors applied) as the print content source | SelectableTextView's textStorage already contains the themed attributed string |
| "Validate each file independently" for multi-file -- error behavior? | Print per-file error to stderr, continue processing remaining files, exit code 0 if at least one file opened successfully, exit code 1 if all files failed | Unix convention: partial success is still success; inform user of failures via stderr |
| Multiple files through `execv` -- delimiter choice? | Newline (`\n`) delimiter in MKDN_LAUNCH_FILE env var | File paths cannot contain newlines; simple and unambiguous parsing |
| Find in preview-only vs side-by-side -- scope? | Find bar operates on the preview pane (SelectableTextView) in both modes | SelectableTextView is present in both modes; the editor pane has its own native find support |
