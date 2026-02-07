# Design Decisions: Default Markdown App

**Feature ID**: default-markdown-app
**Created**: 2026-02-06

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Multi-window state architecture | State Splitting: DocumentState + AppSettings | Incremental refactor following existing @Observable pattern. DocumentState holds per-window file state (URL, content, fileWatcher, viewMode). AppSettings holds app-wide state (theme, hint flag). Minimal disruption to view layer -- each view migrates from one environment object to one or two. | DocumentGroup with ReferenceFileDocument (imposes full document lifecycle with save dialogs unsuitable for viewer-first app); single AppState with window-specific bindings (AppState becomes a god object, complex window routing) |
| D2 | File-open event routing | NSApplicationDelegateAdaptor + FileOpenCoordinator | NSApplicationDelegateAdaptor is the standard SwiftUI-AppKit bridge for receiving system events. FileOpenCoordinator (a shared @Observable singleton) decouples the AppKit delegate from SwiftUI window creation. The App body observes pendingURLs and calls openWindow(value:) for each. | onOpenURL modifier (delivers URLs to the frontmost existing window, does not create new windows); direct NSApp.openURL from delegate (bypasses SwiftUI window lifecycle, risks state inconsistency) |
| D3 | Default handler API | NSWorkspace.setDefaultApplication(at:toOpenContentType:) | The modern, non-deprecated macOS 12+ API for programmatic default handler registration. Takes the app bundle URL and a UTType. Works on the macOS 14.0+ deployment target. Wraps in do/catch for sandbox graceful degradation. | LSSetDefaultRoleHandlerForContentType (deprecated since macOS 12, may be removed); directing users to System Settings > Default Apps (poor UX, does not meet FR-005 requirement for in-app registration) |
| D4 | UTType declaration strategy | UTImportedTypeDeclarations (not Exported) | net.daringfireball.markdown is a well-established ecosystem type that mkdn does not own. Using UTImportedTypeDeclarations tells the system "mkdn understands this type" without claiming ownership. This avoids conflicts with other apps (e.g., iA Writer, Marked 2) that may also declare the type. | UTExportedTypeDeclarations (inappropriate because mkdn does not define or own the Markdown UTType; could cause system conflicts) |
| D5 | Open Recent implementation | NSDocumentController.shared + SwiftUI Commands menu bridge | NSDocumentController handles persistence, system-default item count (~10), and the "Clear Menu" action automatically. We call noteNewRecentDocumentURL() in all file-open paths and read recentDocumentURLs to build a SwiftUI Menu. Minimal custom code for full system-standard behavior. | Manual UserDefaults-based recent file list (reinvents system behavior, must handle count limit, persistence, and Clear Menu manually); SwiftUI DocumentGroup (requires full FileDocument conformance, imposes document lifecycle inappropriate for viewer-first app) |
| D6 | First-launch hint persistence | UserDefaults boolean flag (hasShownDefaultHandlerHint) | Follows the existing themeMode UserDefaults persistence pattern in AppState (now AppSettings). A single boolean is the simplest possible mechanism for "show once, never again" behavior. | Keychain storage (overkill for a non-sensitive preference); file-based flag (unnecessary filesystem interaction); no persistence / session-only (violates FR-006 AC-6 requirement for cross-launch persistence) |
| D7 | Window identity model | WindowGroup(for: URL.self) | SwiftUI-native approach to multi-window on macOS. Each window is bound to a URL value, making window identity explicit. nil URL shows WelcomeView; non-nil URL loads the document. Windows are independently closeable, resizable, and maintain their own DocumentState via @State in DocumentWindow. | Window(id:) with manual lifecycle management (more boilerplate, less SwiftUI-idiomatic); NSWindowController subclass (breaks the SwiftUI model, requires significant AppKit bridging) |
| D8 | Menu commands for multi-window | @FocusedValue(\.documentState) for document-specific commands | Standard SwiftUI mechanism for commands that need access to the focused scene's state. Each DocumentWindow publishes its DocumentState via .focusedSceneValue(). MkdnCommands reads @FocusedValue(\.documentState) for Save, Reload, mode switching. App-wide commands (theme, Set as Default) read AppSettings directly. | Passing DocumentState via init (impossible; Commands protocol does not receive per-window state); global state lookup by window ID (fragile, not SwiftUI-idiomatic); singleton with "active document" tracking (race-prone with multiple windows) |
| D9 | App bundle packaging approach | Build script (scripts/bundle.sh) | SPM's executableTarget does not produce .app bundles. A shell script assembles the bundle from SPM release build output + Info.plist. This is CI-friendly, works with the existing Homebrew formula, and keeps the project SPM-only (no Xcode project). | Xcode project alongside SPM (adds maintenance burden, risks divergence between SPM and Xcode configurations); SwiftPM build plugin (not mature for app bundling, limited ecosystem support); xcodebuild with generated xcodeproj (fragile, deprecated workflow) |

## Interactive Decision: Multi-Window Architecture

**Decision Point**: How to transition from single-window to multi-window architecture.

**User Choice**: State Splitting (Option A) -- Extract DocumentState from AppState, rename remainder to AppSettings.

**Rationale for selection**:
- Incremental approach following existing @Observable patterns
- Minimal disruption to existing view code (environment injection change only)
- Does not impose document lifecycle overhead (no save sheets, no file coordination)
- Preserves viewer-first design philosophy
- Each view migrates independently, enabling parallel implementation work

**Rejected alternative**: DocumentGroup with ReferenceFileDocument -- would have provided automatic Open Recent and multi-window for free, but imposes a full document save/open lifecycle that conflicts with mkdn's viewer-first, minimal-friction design philosophy. Save dialogs on window close would disrupt the "open, render beautifully, close" workflow described in the charter.
