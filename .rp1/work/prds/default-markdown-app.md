# PRD: Default Markdown App

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-06

## Surface Overview

This surface covers registering mkdn as the macOS default handler for Markdown files (`.md`, `.markdown`) via Launch Services, UTType declarations, Info.plist file associations, and file-open event handling. When a user double-clicks a Markdown file in Finder or opens one from any other app, mkdn launches and renders it natively.

## Scope

### In Scope

- **Info.plist `CFBundleDocumentTypes` declarations** for `.md` and `.markdown` file types with silent registration at install/launch
- **UTType declarations** via `UniformTypeIdentifiers` framework for Markdown content types
- **File-open event handling** via `NSApplicationDelegate` to receive and process file-open events from the system
- **"Set as Default Markdown App" menu item** under the application menu for users to explicitly claim default handler status
- **Drag-to-dock-icon support** so users can drag `.md`/`.markdown` files from Finder onto the mkdn dock icon to open them
- **File > Open Recent** support for previously opened Markdown files via `NSDocumentController`

### Out of Scope

- Handling non-Markdown file types (e.g., `.txt`, `.rst`, `.html`)
- Custom URL scheme registration (e.g., `mkdn://`)
- Deep integration with third-party file managers beyond Finder
- Automatic migration from other default Markdown handlers
- File association UI beyond the single menu item

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Declare `CFBundleDocumentTypes` in Info.plist for `net.daringfireball.markdown` and `public.plain-text` subtypes covering `.md` and `.markdown` extensions | Must |
| FR-2 | Register exported/imported UTType declarations via `UniformTypeIdentifiers` for Markdown content types | Must |
| FR-3 | Handle `NSApplicationDelegate.application(_:openFile:)` and `application(_:open:)` events to open files passed by the system | Must |
| FR-4 | Provide a "Set as Default Markdown App" menu item that calls `LSSetDefaultRoleHandlerForContentType` (or equivalent modern API) to claim default handler | Must |
| FR-5 | Accept file drops on the dock icon by handling `NSApplicationDelegate.application(_:open:)` with URLs from Finder drag operations | Must |
| FR-6 | Integrate `NSDocumentController` (or equivalent) to maintain and display a File > Open Recent submenu for previously opened files | Must |
| FR-7 | When opened as default handler, pass the file URL through to `AppState.loadFile(at:)` to render via the existing Markdown pipeline | Must |

### Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-1 | File-open events must begin rendering within 200ms of the app receiving the event (perceived instant launch for already-running app) |
| NFR-2 | All Launch Services interactions must be compatible with macOS 14.0+ (Sonoma) APIs |
| NFR-3 | Default handler registration must not require elevated privileges or accessibility permissions |
| NFR-4 | Open Recent list should persist across app launches using standard macOS document infrastructure |

## Dependencies & Constraints

### Dependencies

| Dependency | Type | Purpose |
|------------|------|--------|
| `UniformTypeIdentifiers` framework | System framework | UTType declarations and Markdown content type registration |
| Launch Services APIs (`LSSetDefaultRoleHandlerForContentType` or modern equivalent) | System API | Programmatic default handler registration from menu item |
| `NSApplicationDelegate` file-open events (`application(_:openFile:)`, `application(_:open:)`) | System API | Receiving file-open requests from Finder, dock, and other apps |
| `NSDocumentController` | System framework | Open Recent menu management and recent file tracking |
| Info.plist `CFBundleDocumentTypes` | Configuration | Declaring supported document types to the system at install time |

### Constraints

- Must work within the existing SwiftUI app lifecycle; may require an `NSApplicationDelegateAdaptor` to bridge AppKit delegate methods into the SwiftUI app
- macOS sandboxing (if adopted later) may restrict Launch Services API access -- design should account for both sandboxed and non-sandboxed builds
- The app currently uses Swift Argument Parser for CLI entry; file-open events from Launch Services arrive through a different code path and must be reconciled with the existing `AppState.loadFile(at:)` flow

## Milestones

| Phase | Milestone | Deliverables |
|-------|-----------|-------------|
| Phase 1: Core Registration | UTType + file-open handling | Info.plist `CFBundleDocumentTypes`, UTType declarations, `NSApplicationDelegateAdaptor` with file-open event handling, integration with `AppState.loadFile(at:)` |
| Phase 2: User Controls | Set as Default menu + dock drag | "Set as Default Markdown App" menu item with Launch Services API call, dock icon drag-and-drop file opening |
| Phase 3: Polish | Open Recent | `NSDocumentController` integration, File > Open Recent submenu, persistence of recent file list across launches |

## Open Questions

- Should mkdn prompt the user on first launch to set itself as default, or wait for the user to discover the menu item?
- How should the app behave if another app is already registered as the default Markdown handler -- show a one-time notification, or stay silent?
- Should Open Recent have a configurable maximum count, or use the macOS system default?

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A1 | `LSSetDefaultRoleHandlerForContentType` (or modern equivalent) is available and functional on macOS 14+ without sandbox restrictions | Menu item to set default would not work; would need to direct users to System Settings | Scope: CLI-launchable |
| A2 | `NSApplicationDelegateAdaptor` can coexist with SwiftUI's `@main` app lifecycle without conflicts | May need to restructure app entry point or use a custom `NSApplication` subclass | Architecture: Two-target layout |
| A3 | The standard `net.daringfireball.markdown` UTType is sufficient to cover all common Markdown files on macOS | Some `.md` files might use non-standard UTTypes and would not trigger mkdn as default handler | Scope: Will Do |
| A4 | Users are comfortable with a menu-driven approach to setting default app (no first-launch prompt) | Users may not discover the feature and continue using their previous default handler | Success: Daily-driver use |

## Discoveries

- **API Deviation**: `NSWorkspace.shared.setDefaultApplication(at:toOpen:)` takes a `UTType` parameter, not `toOpenContentType:` as commonly assumed; the `toOpenContentType:` label does not exist on macOS 14+. -- *Ref: [field-notes.md](../archives/features/default-markdown-app/field-notes.md)*
- **API Deviation**: `NSWorkspace.setDefaultApplication` is non-throwing on macOS 14+; sandbox degradation is silent (the call succeeds but may have no effect), so do/catch error handling is unnecessary. -- *Ref: [field-notes.md](../archives/features/default-markdown-app/field-notes.md)*
- **Workaround**: `swiftlint lint` fails with `Loading sourcekitdInProc.framework failed` due to a system-level SourceKit configuration issue unrelated to code changes; `swiftformat` works as a fallback. -- *Ref: [field-notes.md](../archives/features/default-markdown-app/field-notes.md)*
