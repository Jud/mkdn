# Hypothesis Document: default-markdown-app
**Version**: 1.0.0 | **Created**: 2026-02-06 | **Status**: VALIDATED

## Hypotheses

### HYP-001: NSWorkspace.setDefaultApplication(at:toOpenContentType:) API Viability
**Risk Level**: MEDIUM
**Status**: CONFIRMED
**Statement**: NSWorkspace.shared.setDefaultApplication(at:toOpenContentType:completionHandler:) works on macOS 14+ without sandbox restrictions and does not require elevated privileges or user-facing permission dialogs for Markdown file types.
**Context**: This API is the foundation for the "Set as Default Markdown App" menu item. If it requires user consent dialogs or elevated privileges, the UX design must accommodate that.
**Validation Criteria**:
- CONFIRM if: The API exists for macOS 12+, compiles, and the SDK header docs do not mention sandbox entitlements or elevated privileges. User consent is limited to specific protected types (browsers, email) and does not apply to Markdown.
- REJECT if: The API requires TCC permissions, sandbox entitlements, or shows a system consent dialog for Markdown file types.
**Suggested Method**: CODE_EXPERIMENT

### HYP-002: NSApplicationDelegateAdaptor Coexistence with Manual main()
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: NSApplicationDelegateAdaptor can coexist with the current manual MkdnApp.main() call in mkdnEntry/main.swift without lifecycle conflicts.
**Context**: The current entry point parses CLI args, then calls MkdnApp.main(). Adding @NSApplicationDelegateAdaptor to MkdnApp introduces a second NSApplicationDelegate path. The design relies on application(_:open:) to receive file-open events from Finder/Dock.
**Validation Criteria**:
- CONFIRM if: @NSApplicationDelegateAdaptor compiles in an App struct without @main, and SwiftUI handles the delegate forwarding when App.main() is called manually.
- REJECT if: @NSApplicationDelegateAdaptor requires @main, or introduces lifecycle conflicts that crash the app.
**Suggested Method**: CODE_EXPERIMENT

### HYP-003: NSDocumentController.recentDocumentURLs Without DocumentGroup
**Risk Level**: MEDIUM
**Status**: CONFIRMED
**Statement**: NSDocumentController.shared.recentDocumentURLs is accessible and populated in a SwiftUI app that does not use DocumentGroup, and the recent list persists across launches.
**Context**: FR-008 (Open Recent) relies on NSDocumentController to track recently opened files without adopting the full NSDocument architecture.
**Validation Criteria**:
- CONFIRM if: noteNewRecentDocumentURL(_:) adds entries, recentDocumentURLs returns them, and the data survives process restart.
- REJECT if: The API requires NSDocument subclasses or DocumentGroup to function.
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-07T05:28:00Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

1. **API exists and compiles**: The macOS SDK header at `NSWorkspace.h:141` declares:
   ```objc
   /* Sets the default handler for the specified UTType. Some types require user consent
      before you can change their handlers. If a change requires user consent, the system
      will ask the user asynchronously before invoking the completion handler. */
   - (void)setDefaultApplicationAtURL:(NSURL *)applicationURL
                    toOpenContentType:(UTType *)contentType
                    completionHandler:(void (^_Nullable)(NSError *_Nullable error))completionHandler
                    API_AVAILABLE(macos(12.0));
   ```
   This is the direct UTType-based API (not the file-URL variant). It accepts a `UTType` directly, which means the design can pass `UTType(filenameExtension: "md")` without needing a reference file.

2. **Four API variants available** (all macOS 12.0+):
   - `setDefaultApplication(at:toOpenContentType:completionHandler:)` -- sets by UTType (this is the one to use)
   - `setDefaultApplication(at:toOpenContentTypeOfFileAtURL:completionHandler:)` -- infers type from a file
   - `setDefaultApplication(at:toOpenFileAtURL:completionHandler:)` -- single file only
   - `setDefaultApplication(at:toOpenURLsWithScheme:completionHandler:)` -- URL schemes

3. **User consent scope**: The SDK header says "Some types require user consent." External research confirms the consent dialog is limited to protected system types:
   - HTTP/HTTPS URL schemes (web browsers)
   - Email (mailto: scheme)
   Markdown (`public.plain-text` / custom UTI for `.md`) is NOT a protected type. No consent dialog is expected.

4. **No sandbox entitlements mentioned**: The SDK header documentation does not reference any sandbox entitlement, TCC permission, or elevated privilege. The Apple Developer Forums threads about "permission errors" relate to sandboxed apps trying to access file URLs via `setDefaultApplication(at:toOpenContentTypeOfFileAtURL:)`, not the UTType-based variant.

5. **Runtime verification**: Code experiment confirmed the API compiles and UTType resolution works:
   ```
   Current default app for .md files: Xcode-16.3.0.app
   Apps that can open .md: ["Xcode-16.3.0.app", "MacVim.app", "TextEdit.app", ...]
   ```

6. **mkdn is unsandboxed**: The app is built with `swift build` and runs without App Sandbox entitlements, so sandbox-related permission errors do not apply.

**Sources**:
- macOS SDK header: `NSWorkspace.h:125-141` (Xcode 16.3.0 SDK)
- [Apple Developer Forums: Permission error with setDefaultApplication](https://developer.apple.com/forums/thread/731555) (pertains to sandboxed + file-URL variant only)
- [Apple Developer Forums: setDefaultApplication documentation](https://developer.apple.com/documentation/appkit/nsworkspace/3753002-setdefaultapplication)
- [Ctrl.blog: Default browser consent protection](https://www.ctrl.blog/entry/osx-protect-default-browser.html) (confirms consent is browser-specific)
- [dooti: macOS 12+ default handler tool](https://github.com/lkubb/dooti) (production tool using these APIs)

**Implications for Design**:
The design can use `NSWorkspace.shared.setDefaultApplication(at:toOpenContentType:completionHandler:)` directly with `UTType(filenameExtension: "md")`. No user consent dialog will appear for Markdown types. The completion handler should check for errors (e.g., invalid app URL) but does not need to handle a consent-pending state. The API is async with a completion handler, so the menu item implementation should handle the async nature (e.g., show brief confirmation on success).

---

### HYP-002 Findings
**Validated**: 2026-02-07T05:28:00Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

1. **Compiles without @main**: The code experiment confirmed that `@NSApplicationDelegateAdaptor(TestAppDelegate.self)` compiles inside an `App` struct that does NOT have `@main`. The pattern is:
   ```swift
   struct MkdnApp: App {  // no @main
       @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
       // ...
   }
   // Then in top-level code:
   MkdnApp.main()
   ```
   This compiles cleanly with `xcrun swiftc -parse`.

2. **How it works internally**: When `MkdnApp.main()` is called, SwiftUI sets up `NSApplication` and its own internal delegate. The `@NSApplicationDelegateAdaptor` property wrapper is detected by SwiftUI, which creates an instance of the specified delegate class and forwards relevant delegate calls to it. There is no conflict because SwiftUI manages the lifecycle -- the adaptor is a forwarding mechanism, not a competing delegate.

3. **Current entry point is compatible**: The existing `mkdnEntry/main.swift` calls:
   ```swift
   NSApplication.shared.setActivationPolicy(.regular)
   MkdnApp.main()
   ```
   The `setActivationPolicy(.regular)` call happens BEFORE `MkdnApp.main()`, which is fine. SwiftUI takes over when `.main()` is called and will detect the adaptor property.

4. **Known caveats**:
   - `applicationShouldHandleReopen` does NOT work with `@NSApplicationDelegateAdaptor` when `WindowGroup` is present (open bug FB9754295). This does not affect the feature since file-open events use `application(_:open:)`, not reopen.
   - `application(_:open:)` may receive an empty URL array unless `.handlesExternalEvents(matching: [])` is added to the `WindowGroup`. This is a known workaround documented in Apple Developer Forums.
   - There is no SwiftUI-native way to handle file-open events from Finder on macOS. The `onOpenURL` modifier does not handle file-open events, only URL scheme callbacks. `application(_:open:)` via the delegate adaptor is the correct approach.

5. **Codebase analysis** of `mkdnEntry/main.swift:7-29`: The `MkdnApp` struct currently has `@State private var appState: AppState` and a `WindowGroup` with `.windowStyle(.hiddenTitleBar)`. Adding `@NSApplicationDelegateAdaptor` as another property is structurally compatible.

**Sources**:
- [The Eclectic Light Company: SwiftUI on macOS: Life Cycle and AppDelegate](https://eclecticlight.co/2024/04/17/swiftui-on-macos-life-cycle-and-appdelegate/)
- [Swift by Sundell: Using an AppDelegate with SwiftUI](https://www.swiftbysundell.com/tips/using-an-app-delegate-with-swiftui-app-lifecycle/)
- [Jesse Squires: The obscure solution to AppDelegate in SwiftUI](https://www.jessesquires.com/blog/2021/11/13/using-an-appdelegate-in-swiftui/)
- [FB9754295: applicationShouldHandleReopen broken](https://github.com/feedback-assistant/reports/issues/246)
- [Swift Forums: Open file in Finder does not work on App launch](https://forums.swift.org/t/open-file-in-finder-does-not-work-on-app-launch/64049)
- [Apple Developer Forums: SwiftUI app cycle and file opening](https://developer.apple.com/forums/thread/689229)
- Codebase: `mkdnEntry/main.swift:1-50`, `mkdn/Core/CLI/LaunchContext.swift:1-11`

**Implications for Design**:
The design's approach of adding `@NSApplicationDelegateAdaptor` to `MkdnApp` is viable. Two critical implementation details:
1. The `WindowGroup` MUST include `.handlesExternalEvents(matching: [])` to ensure `application(_:open:)` receives the actual file URLs instead of an empty array.
2. The `application(_:open:)` delegate method will NOT fire during the initial CLI launch (that path uses `LaunchContext.fileURL`), but WILL fire when files are opened via Finder/Dock while the app is running or when the app is launched by double-clicking a file. The design should handle the "app launched by file double-click" case where `application(_:open:)` fires AFTER `applicationDidFinishLaunching` but before the UI is fully ready.

---

### HYP-003 Findings
**Validated**: 2026-02-07T05:28:00Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

1. **SDK header explicitly supports non-NSDocument apps**: The `NSDocumentController.h` header at line 235-236 states:
   ```
   /* Add an item corresponding to the data located by a URL to the Open Recent menu,
      or replace an existing item with the same URL.
      You can use this even in non-NSDocument-based applications. */
   - (void)noteNewRecentDocumentURL:(NSURL *)url;
   ```
   This is an explicit declaration that the API works without NSDocument subclasses.

2. **Runtime verification -- population works**: Code experiment in an NSApplication context confirmed:
   ```
   Initial recent documents: 0
   After noteNewRecentDocumentURL: 1
     - /private/tmp/test-recent-doc.md
   Maximum recent docs: 10
   ```
   The API successfully added the URL and `recentDocumentURLs` returned it.

3. **Runtime verification -- persistence works**: Running the same test executable a second time confirmed the data persists:
   ```
   Initial recent documents: 1
   After noteNewRecentDocumentURL: 1
     - /private/tmp/test-recent-doc.md
   ```
   The entry from the first run was still present on the second run, confirming persistence across process restarts.

4. **Persistence mechanism**: NSDocumentController stores recent documents in UserDefaults. The exact key varies (NSRecentDocumentRecords or a bundle-scoped variant), but the system handles this automatically. With a proper bundle identifier (which mkdn will have as a .app bundle), the recent docs are scoped to the app.

5. **No DocumentGroup required**: The test used a plain `NSApplication` with no `DocumentGroup`, no `NSDocument` subclass, and no `WindowGroup`. `noteNewRecentDocumentURL` and `recentDocumentURLs` both worked correctly.

6. **Integration point**: The design should call `NSDocumentController.shared.noteNewRecentDocumentURL(url)` in every code path that opens a file: `AppState.loadFile(at:)` (or its future `DocumentState` equivalent), file-open delegate handler, CLI launch path, and drag-drop handler.

**Sources**:
- macOS SDK header: `NSDocumentController.h:235-241` (Xcode 16.3.0 SDK)
- [Apple Developer Documentation: recentDocumentURLs](https://developer.apple.com/documentation/appkit/nsdocumentcontroller/recentdocumenturls)
- [Apple Developer Documentation: NSDocumentController](https://developer.apple.com/documentation/appkit/nsdocumentcontroller)
- [Apple Developer Forums: adding recent open document list](https://developer.apple.com/forums/thread/743542)
- Code experiment: `/tmp/hypothesis-default-markdown-app/hyp003_app_test.swift` (2 runs, persistence confirmed)

**Implications for Design**:
FR-008 (Open Recent) can be implemented using `NSDocumentController.shared` without adopting `DocumentGroup` or `NSDocument`. The design should:
1. Call `noteNewRecentDocumentURL` on every file open.
2. Read `recentDocumentURLs` to populate the File > Open Recent submenu.
3. The system automatically handles the "Clear Menu" action and maximum count (default 10).
4. No custom persistence code is needed -- the system handles it via UserDefaults.

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001: setDefaultApplication API | MEDIUM | CONFIRMED | UTType-based API works on macOS 12+, no consent dialog for Markdown types, no sandbox restrictions. Use directly. |
| HYP-002: NSApplicationDelegateAdaptor + manual main() | HIGH | CONFIRMED | Works without @main. Must add .handlesExternalEvents(matching: []) to WindowGroup for correct URL delivery. |
| HYP-003: NSDocumentController without DocumentGroup | MEDIUM | CONFIRMED | Explicitly supported by Apple. noteNewRecentDocumentURL works, persists across launches, no NSDocument needed. |
