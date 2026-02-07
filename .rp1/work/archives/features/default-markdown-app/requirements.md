# Requirements Specification: Default Markdown App

**Feature ID**: default-markdown-app
**Parent PRD**: [Default Markdown App](../../prds/default-markdown-app.md)
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-06

## 1. Feature Overview

mkdn must register itself with macOS as a handler for Markdown files so that users can open `.md` and `.markdown` files from Finder, the dock, or any other application and have them render natively in mkdn. This includes system-level file type declarations, a user-facing mechanism to claim default handler status, drag-to-dock support, and recent file tracking -- all in service of the charter goal that mkdn becomes the developer's daily-driver Markdown tool.

## 2. Business Context

### 2.1 Problem Statement

Developers who use mkdn from the terminal have no way to open Markdown files from Finder or other GUI-based workflows and have them land in mkdn. Double-clicking a `.md` file opens whatever app macOS currently associates with that type (often Xcode, TextEdit, or a browser). This breaks the seamless workflow the charter envisions and prevents mkdn from becoming the single, go-to Markdown tool.

### 2.2 Business Value

Claiming default handler status removes the last major friction point between "developer generates Markdown artifact" and "developer reads it in mkdn." It bridges the gap between terminal-centric and GUI-centric file opening, making mkdn the universal entry point for Markdown on the user's Mac. This directly supports the charter's success criterion of daily-driver use.

### 2.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| File-open event handling | 100% of `.md` and `.markdown` files opened via Finder/dock arrive in mkdn when set as default | Manual verification on macOS 14+ |
| First-launch hint engagement | Hint appears exactly once, never reappears after dismissal or action | Manual verification; UserDefaults persistence check |
| Open Recent accuracy | Previously opened files appear in File > Open Recent and can be re-opened | Manual verification across app restarts |
| Perceived responsiveness | File begins rendering within 200ms of the app receiving a file-open event (already-running app) | Stopwatch / profiling |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Terminal-centric developer | Primary user. Works from terminal, generates Markdown via LLMs/agents, currently launches mkdn via CLI. Wants Finder/dock opening to also route to mkdn. | Primary beneficiary of default handler registration |
| GUI-oriented developer | Occasionally uses Finder to browse project directories. Expects double-click on `.md` to open a capable viewer. | Benefits from file association and dock drag |
| New user | Just installed mkdn. Needs a gentle nudge to set it as default without being pressured. | Target of the first-launch hint |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| End user | Seamless file opening from any macOS entry point; no manual configuration beyond a single action |
| Project (charter) | Daily-driver adoption; mkdn as the single Markdown tool on the user's Mac |

## 4. Scope Definition

### 4.1 In Scope

- System-level file type declarations for `.md` and `.markdown` extensions
- UTType registration for Markdown content types
- Handling file-open events from Finder, dock drag, and other applications
- "Set as Default Markdown App" menu item under the application menu
- Subtle, non-modal first-launch hint with actionable "Set as Default" button
- Dock icon drag-and-drop file opening
- File > Open Recent submenu with macOS system default item count
- Multi-window behavior: file-open events while app is running create a new window

### 4.2 Out of Scope

- Handling non-Markdown file types (`.txt`, `.rst`, `.html`, etc.)
- Custom URL scheme registration (e.g., `mkdn://`)
- Deep integration with third-party file managers beyond Finder
- Automatic migration from other default Markdown handlers
- File association UI beyond the single menu item and first-launch hint
- Configurable Open Recent count
- First-launch prompt as a blocking modal dialog

### 4.3 Assumptions

| ID | Assumption | Risk if Wrong |
|----|------------|---------------|
| A1 | The macOS API for programmatic default handler registration is available on macOS 14+ without sandbox restrictions | Menu item would not work; users would need to be directed to System Settings > Default Apps |
| A2 | NSApplicationDelegateAdaptor can coexist with the SwiftUI @main app lifecycle without conflicts | May require restructuring the app entry point |
| A3 | The standard `net.daringfireball.markdown` UTType covers the vast majority of `.md` files on macOS | Some files with non-standard UTTypes might not trigger mkdn as default |
| A4 | Multi-window support can be achieved through the existing app architecture or with reasonable extension | May require significant architectural changes if the current design is strictly single-window |

## 5. Functional Requirements

### FR-001: Markdown File Type Declaration
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The application must declare support for `.md` and `.markdown` file extensions via CFBundleDocumentTypes, covering the `net.daringfireball.markdown` and related content types, so that macOS recognizes mkdn as a capable handler for Markdown files.
- **Rationale**: Without file type declarations, macOS will never offer mkdn as an option for opening Markdown files, and the app cannot be set as default.
- **Acceptance Criteria**:
  - AC-1: After installation, macOS lists mkdn in the "Open With" context menu for `.md` files in Finder.
  - AC-2: After installation, macOS lists mkdn in the "Open With" context menu for `.markdown` files in Finder.
  - AC-3: The declarations are compatible with macOS 14.0+ (Sonoma).

### FR-002: UTType Registration
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The application must register exported and/or imported UTType declarations via the UniformTypeIdentifiers framework for Markdown content types, ensuring proper type conformance hierarchy.
- **Rationale**: UTType declarations are the modern macOS mechanism for file type identity. Without them, file associations may be unreliable or incomplete.
- **Acceptance Criteria**:
  - AC-1: UTType declarations are present and correctly reference `net.daringfireball.markdown`.
  - AC-2: The type conforms to the expected supertype hierarchy (e.g., public.plain-text, public.text, public.data).
  - AC-3: Both `.md` and `.markdown` extensions are covered by the declared types.

### FR-003: File-Open Event Handling
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The application must handle file-open events from the system (via NSApplicationDelegate methods) so that when macOS sends a file-open request -- from Finder double-click, another application, or system services -- mkdn receives the file URL and renders it.
- **Rationale**: File type declarations alone are not sufficient; the app must actively receive and process incoming file-open events to complete the integration.
- **Acceptance Criteria**:
  - AC-1: Double-clicking a `.md` file in Finder (when mkdn is the default) launches mkdn and renders the file.
  - AC-2: Double-clicking a `.md` file when mkdn is already running opens the file in a new window.
  - AC-3: The file URL is routed through the existing document loading flow to render via the Markdown pipeline.
  - AC-4: File-open events for `.markdown` files behave identically to `.md` files.

### FR-004: Multi-Window File Opening
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: When a file-open event arrives while mkdn is already running, the application must create a new window for the incoming file rather than replacing the content of the existing window.
- **Rationale**: Users frequently work with multiple Markdown files simultaneously. Replacing the current document would disrupt their workflow and lose unsaved context.
- **Acceptance Criteria**:
  - AC-1: Opening a second file via Finder while mkdn is running results in two separate windows, each displaying its respective file.
  - AC-2: Each window operates independently (can be closed, resized, scrolled without affecting other windows).
  - AC-3: Opening N files simultaneously (e.g., selecting multiple in Finder and pressing Enter) creates N windows.

### FR-005: Set as Default Menu Item
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The application must provide a "Set as Default Markdown App" menu item under the application menu that, when activated, registers mkdn as the system default handler for Markdown files using the appropriate macOS API.
- **Rationale**: Users need an explicit, discoverable mechanism to claim default handler status. A menu item is the standard macOS pattern for this action.
- **Acceptance Criteria**:
  - AC-1: A "Set as Default Markdown App" item is visible in the application menu (mkdn menu).
  - AC-2: Activating the menu item registers mkdn as the default handler for `.md` and `.markdown` files.
  - AC-3: After activation, double-clicking a `.md` file in Finder opens it in mkdn.
  - AC-4: The registration does not require elevated privileges or accessibility permissions.
  - AC-5: The menu item is always available (not conditionally hidden).

### FR-006: First-Launch Hint
- **Priority**: Must Have
- **User Type**: New users
- **Requirement**: On the very first launch of mkdn, the application must display a subtle, non-modal hint (e.g., a brief banner or inline notification) suggesting the user set mkdn as their default Markdown app. The hint must include an actionable "Set as Default" button that directly triggers registration, and a dismiss option. Once the user either acts on the hint or dismisses it, the hint must never appear again (persisted across launches).
- **Rationale**: New users may not discover the menu item on their own. A gentle, non-blocking nudge increases adoption of the default handler feature without being intrusive. The charter's success criterion depends on daily-driver use, which is more likely if mkdn is the default handler.
- **Acceptance Criteria**:
  - AC-1: On first launch, a non-modal hint appears suggesting the user set mkdn as default.
  - AC-2: The hint includes a "Set as Default" button that triggers default handler registration when clicked.
  - AC-3: The hint includes a dismiss option (e.g., close button or "Not now" text).
  - AC-4: After clicking "Set as Default," the hint disappears and mkdn is registered as default.
  - AC-5: After dismissing the hint, it never appears again on subsequent launches.
  - AC-6: The hint's shown/dismissed state is persisted (survives app restart).
  - AC-7: The hint does not block user interaction with the rest of the application.
  - AC-8: If another app is already the default Markdown handler, no separate notification is shown -- the first-launch hint is the only mechanism.

### FR-007: Dock Icon Drag-and-Drop
- **Priority**: Must Have
- **User Type**: GUI-oriented developers
- **Requirement**: Users must be able to drag `.md` or `.markdown` files from Finder onto the mkdn dock icon to open them in the application.
- **Rationale**: Drag-to-dock is a standard macOS interaction pattern that users expect from any application that handles files. Supporting it reduces friction for GUI-oriented workflows.
- **Acceptance Criteria**:
  - AC-1: Dragging a `.md` file from Finder onto the mkdn dock icon opens the file in mkdn.
  - AC-2: Dragging a `.markdown` file from Finder onto the mkdn dock icon opens the file in mkdn.
  - AC-3: If mkdn is not running, the drag launches the app and opens the file.
  - AC-4: If mkdn is already running, the drag opens the file in a new window.
  - AC-5: Dragging multiple files onto the dock icon opens each in a separate window.

### FR-008: Open Recent
- **Priority**: Must Have
- **User Type**: All users
- **Requirement**: The application must maintain a File > Open Recent submenu that lists previously opened Markdown files. The list must use the macOS system default item count (typically 10) and persist across application launches.
- **Rationale**: Open Recent is a standard macOS feature that users expect. It provides quick access to frequently used files and supports the daily-driver workflow.
- **Acceptance Criteria**:
  - AC-1: A File > Open Recent submenu exists in the menu bar.
  - AC-2: Files opened via any method (CLI, Finder, dock drag, Open Recent itself) are added to the recent list.
  - AC-3: Selecting a file from Open Recent opens it in a new window.
  - AC-4: The recent list persists across app launches.
  - AC-5: The recent list uses the macOS system default maximum count.
  - AC-6: A "Clear Menu" option is available at the bottom of the Open Recent submenu.

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| ID | Requirement | Rationale |
|----|-------------|-----------|
| NFR-001 | File-open events must begin rendering within 200ms of the app receiving the event (already-running app) | Users expect perceived-instant response when switching to an already-running app via Finder |
| NFR-002 | The first-launch hint must appear within 500ms of the main window being displayed | A delayed hint feels broken; an immediate hint feels like part of the welcome experience |

### 6.2 Security Requirements

| ID | Requirement | Rationale |
|----|-------------|-----------|
| NFR-003 | Default handler registration must not require elevated privileges, accessibility permissions, or any special entitlements | Users should never see a system permission dialog for this feature |
| NFR-004 | The application must handle file-open events only for declared Markdown types; it must not process or attempt to render files of other types received via unexpected system events | Prevents undefined behavior from malformed or unexpected input |

### 6.3 Usability Requirements

| ID | Requirement | Rationale |
|----|-------------|-----------|
| NFR-005 | The "Set as Default Markdown App" menu item must use standard macOS menu conventions (placement in app menu, standard capitalization) | Consistency with macOS platform expectations |
| NFR-006 | The first-launch hint must be visually subtle and consistent with the app's theme (Solarized) | The charter's design philosophy demands obsessive attention to visual detail; the hint must feel native, not like a popup ad |
| NFR-007 | After setting mkdn as default, the user should receive brief visual confirmation (e.g., the hint updates to "Done" or a brief checkmark animation) | Users need feedback that the action succeeded |

### 6.4 Compatibility Requirements

| ID | Requirement | Rationale |
|----|-------------|-----------|
| NFR-008 | All file association and Launch Services interactions must be compatible with macOS 14.0+ (Sonoma) | Project minimum deployment target |
| NFR-009 | The feature must work in both sandboxed and non-sandboxed builds, or gracefully degrade in a sandboxed environment | Future-proofing for potential App Store distribution |

## 7. User Stories

### STORY-001: Set mkdn as default from first-launch hint
- **As a** new mkdn user
- **I want to** see a gentle suggestion to set mkdn as my default Markdown app when I first launch it
- **So that** I can quickly configure mkdn as my daily-driver without hunting through menus

**Acceptance Scenarios**:

- GIVEN mkdn has never been launched before
  WHEN the application starts and the main window appears
  THEN a non-modal hint appears with a "Set as Default" button and a dismiss option

- GIVEN the first-launch hint is visible
  WHEN I click "Set as Default"
  THEN mkdn is registered as the system default for `.md` and `.markdown` files AND the hint disappears with brief confirmation

- GIVEN the first-launch hint is visible
  WHEN I dismiss the hint
  THEN the hint disappears AND it never appears again on subsequent launches

- GIVEN I dismissed the first-launch hint previously
  WHEN I launch mkdn again
  THEN no hint appears

### STORY-002: Open Markdown file from Finder
- **As a** developer browsing project files in Finder
- **I want to** double-click a `.md` file and have it open in mkdn
- **So that** I can read and review Markdown content without switching to the terminal

**Acceptance Scenarios**:

- GIVEN mkdn is set as the default Markdown handler AND mkdn is not running
  WHEN I double-click a `.md` file in Finder
  THEN mkdn launches AND the file is rendered in a new window

- GIVEN mkdn is set as the default Markdown handler AND mkdn is already running with a file open
  WHEN I double-click a different `.md` file in Finder
  THEN a new mkdn window opens with the second file AND the first window remains unchanged

### STORY-003: Drag file to dock icon
- **As a** developer who prefers drag-and-drop workflows
- **I want to** drag a Markdown file from Finder onto the mkdn dock icon
- **So that** I can open it quickly without changing my default handler or using the terminal

**Acceptance Scenarios**:

- GIVEN mkdn is running
  WHEN I drag a `.md` file from Finder onto the mkdn dock icon
  THEN the file opens in a new mkdn window

- GIVEN mkdn is not running
  WHEN I drag a `.md` file from Finder onto the mkdn dock icon
  THEN mkdn launches AND the file is rendered in a new window

### STORY-004: Set mkdn as default from menu
- **As a** user who dismissed the first-launch hint or wants to re-confirm default status
- **I want to** find a "Set as Default Markdown App" option in the application menu
- **So that** I can register mkdn as default at any time

**Acceptance Scenarios**:

- GIVEN mkdn is running
  WHEN I open the mkdn application menu
  THEN I see a "Set as Default Markdown App" menu item

- GIVEN I click "Set as Default Markdown App"
  WHEN the registration completes
  THEN mkdn is the system default handler for `.md` and `.markdown` files AND I receive brief visual confirmation

### STORY-005: Re-open a recently viewed file
- **As a** developer who frequently revisits the same Markdown files
- **I want to** quickly re-open a file I viewed recently from the File > Open Recent menu
- **So that** I do not have to navigate to the file in Finder or remember its path

**Acceptance Scenarios**:

- GIVEN I have previously opened `README.md` in mkdn
  WHEN I go to File > Open Recent
  THEN `README.md` appears in the list

- GIVEN `README.md` is in my Open Recent list
  WHEN I click on it
  THEN it opens in a new mkdn window

- GIVEN I have opened more files than the system default maximum
  WHEN I go to File > Open Recent
  THEN only the most recent files (up to system default count) are shown

- GIVEN I want to clear my recent file history
  WHEN I click "Clear Menu" in the Open Recent submenu
  THEN all items are removed from the recent list

## 8. Business Rules

| ID | Rule | Rationale |
|----|------|-----------|
| BR-001 | The first-launch hint must appear at most once per installation. The "shown" state is persisted via UserDefaults. | Prevents nagging; respects user choice |
| BR-002 | The first-launch hint is the only mechanism for proactively suggesting default handler status. The app must not display additional prompts, notifications, or dialogs about default handler status at any other time. | The user chose "silent after hint" -- no separate notification about existing defaults |
| BR-003 | Every file-open event (regardless of source: Finder, dock, CLI, Open Recent) must result in a new window when the app is already running. | Consistent multi-window behavior across all entry points |
| BR-004 | Only `.md` and `.markdown` file extensions are handled. The app must not register for or attempt to handle other plain-text or markup formats. | Scope constraint from PRD |
| BR-005 | Open Recent uses the macOS system default item count with no user configuration option. | Simplicity; avoids unnecessary preferences UI |

## 9. Dependencies & Constraints

### Dependencies

| Dependency | Purpose |
|------------|---------|
| UniformTypeIdentifiers framework | UTType declarations and Markdown content type registration |
| Launch Services APIs (LSSetDefaultRoleHandlerForContentType or modern equivalent) | Programmatic default handler registration |
| NSApplicationDelegate file-open events | Receiving file-open requests from Finder, dock, and other apps |
| NSDocumentController (or equivalent) | Open Recent menu management and recent file tracking |
| Info.plist CFBundleDocumentTypes | Declaring supported document types to the system |
| Existing AppState.loadFile(at:) flow | Rendering files received via system events through the existing Markdown pipeline |

### Constraints

| ID | Constraint | Impact |
|----|-----------|--------|
| C-001 | Must work within the existing SwiftUI app lifecycle; may require NSApplicationDelegateAdaptor to bridge AppKit delegate methods | Architectural consideration for implementation |
| C-002 | macOS sandboxing (if adopted later) may restrict Launch Services API access | Feature must degrade gracefully in sandboxed builds |
| C-003 | The app currently uses Swift Argument Parser for CLI entry; file-open events arrive through a different code path | Both paths must converge on the same document loading flow |
| C-004 | Multi-window support must coexist with the existing single-window architecture | May require changes to AppState or window management |

## 10. Clarifications Log

| # | Question | Answer | Date |
|---|----------|--------|------|
| 1 | Should mkdn prompt the user on first launch to set itself as default, or wait for the user to discover the menu item? | Subtle, non-modal hint on first launch with actionable "Set as Default" button and dismiss option. Once acted upon or dismissed, never shown again (persisted via UserDefaults). | 2026-02-06 |
| 2 | How should the app behave if another app is already registered as the default Markdown handler? | The first-launch hint is sufficient. No separate notification about existing defaults. If the user dismisses the hint, respect that silently. | 2026-02-06 |
| 3 | Should Open Recent have a configurable maximum count, or use the macOS system default? | Use macOS system default (typically 10 items). No configuration needed. | 2026-02-06 |
| 4 | When a file-open event arrives while mkdn is already running, should it replace the current document or open a new window? | Open a new window. Multi-window support for all file-open events. | 2026-02-06 |
| 5 | What should happen when the user interacts with the first-launch hint? | The hint includes an actionable "Set as Default" button that directly triggers registration, plus a dismiss option. Once dismissed or acted upon, it never appears again. | 2026-02-06 |
