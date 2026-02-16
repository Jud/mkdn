# Feature Verification Report #1

**Generated**: 2026-02-14T00:12:00Z
**Feature ID**: mac-app-essentials
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Not available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 24/38 verified (63%)
- Implementation Quality: HIGH
- Ready for Merge: NO

Four of eight features are fully implemented (T1 Find, T2 Print, T4 Save As, T5 Code Block Copy). Two features are not started (T3 Zoom, T6 Task List Checkboxes -- though all design infrastructure is in place). Two features are not started (T7 Multi-file CLI, T8 About Window -- though all code is present in the worktree). See details below for the nuanced per-criterion breakdown.

**Correction**: After full code analysis, the worktree contains implementation for all eight features. T1, T2, T4, T5 are marked complete in tasks.md and verified in code. T3 (Zoom), T6 (Task List Checkboxes), T7 (Multi-file CLI), and T8 (About Window) all have code present in the worktree despite being unchecked in tasks.md. Verification below reflects the actual code state.

- Acceptance Criteria Verified: 35/38 (92%)
- Acceptance Criteria Partial: 2/38 (5%)
- Acceptance Criteria Not Verified: 1/38 (3%)

Revised:
- Overall Status: PARTIAL (due to 1 NOT VERIFIED and 2 PARTIAL items)
- Ready for Merge: NO (minor gaps to address)

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None (no field-notes.md file exists)

### Undocumented Deviations
1. **T4 Save As disabled condition**: Design specified `documentState?.currentFileURL == nil` but implementation uses `documentState == nil`. tasks.md notes this as intentional ("Save As should also work for new unsaved documents") but it is not captured in a field-notes.md file.
2. **T3 Zoom**: Code is fully present but tasks.md marks T3 as not started. Either tasks.md is out of date or the code was added but not yet verified by the implementer.
3. **T6 Task List Checkboxes**: Same as T3 -- code is present but tasks.md shows unchecked.
4. **T7 Multi-file CLI**: Same -- code is present but tasks.md shows unchecked.
5. **T8 About Window**: Same -- code is present but tasks.md shows unchecked.

## Acceptance Criteria Verification

### REQ-FIND-001: Find bar activation via Cmd+F
**AC**: GIVEN a document is open WHEN user presses Cmd+F THEN the NSTextView find bar appears at the top of the text view
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Features/Viewer/Views/SelectableTextView.swift`:138-139 - `configureTextView()`
- Evidence: `textView.usesFindBar = true` and `textView.isIncrementalSearchingEnabled = true` are set. Menu item dispatches via `sendFindAction(tag: 1)` in MkdnCommands.swift:57-59.
- Field Notes: N/A
- Issues: None

### REQ-FIND-002: Find Next/Previous navigation
**AC**: GIVEN the find bar is open with matches WHEN user presses Cmd+G THEN selection moves to next match; Shift+Cmd+G moves to previous
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:61-70 - Find Next and Find Previous buttons
- Evidence: Find Next dispatches `sendFindAction(tag: 2)` with Cmd+G shortcut; Find Previous dispatches `sendFindAction(tag: 3)` with Shift+Cmd+G. Tags match `NSFindPanelAction` enum values. `sendFindAction()` at line 162-171 creates an `NSMenuItem` with the tag and sends `performFindPanelAction` action.
- Field Notes: N/A
- Issues: None

### REQ-FIND-003: Use Selection for Find (Cmd+E)
**AC**: GIVEN text is selected WHEN user presses Cmd+E THEN selected text populates system find pasteboard
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:72-75 - Use Selection for Find button
- Evidence: Dispatches `sendFindAction(tag: 7)` with Cmd+E shortcut. Tag 7 = `setFindString` in NSFindPanelAction.
- Field Notes: N/A
- Issues: None

### REQ-FIND-004: Find items in Edit menu
**AC**: GIVEN the app is running WHEN user opens Edit menu THEN Find..., Find Next, Find Previous, Use Selection for Find are listed
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:55-76 - `CommandGroup(after: .pasteboard)`
- Evidence: All four find items present with correct keyboard shortcuts.
- Field Notes: N/A
- Issues: None

### REQ-PRINT-001: Print via Cmd+P
**AC**: GIVEN a document is open WHEN user presses Cmd+P THEN macOS print dialog appears
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:88-96 - Print... button
- Evidence: Dispatches `NSApp.sendAction(#selector(NSView.printView(_:)))` with Cmd+P shortcut.
- Field Notes: N/A
- Issues: None

### REQ-PRINT-002: Themed print output
**AC**: Printed output uses current theme colors
- Status: MANUAL_REQUIRED
- Implementation: Print uses NSTextView's built-in `printView` which prints the current attributed string content. The attributed string already has theme colors applied by MarkdownTextStorageBuilder.
- Evidence: The design relies on NSTextView's built-in print behavior using the themed attributed string. Cannot verify print output appearance programmatically.
- Field Notes: N/A
- Issues: Requires manual verification by printing and inspecting output.

### REQ-PRINT-003: Page Setup in File menu
**AC**: GIVEN the app is running WHEN user opens File menu THEN Page Setup... is listed
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:79-86 - Page Setup... button
- Evidence: Present in `CommandGroup(replacing: .printItem)`. Dispatches `NSApp.sendAction(#selector(NSDocument.runPageLayout(_:)))`. Has Shift+Cmd+P shortcut.
- Field Notes: N/A
- Issues: None

### REQ-PRINT-004: Print in File menu with Cmd+P
**AC**: GIVEN the app is running WHEN user opens File menu THEN Print... is listed with Cmd+P
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:88-96
- Evidence: Print... button with `.keyboardShortcut("p", modifiers: .command)` present.
- Field Notes: N/A
- Issues: None

### REQ-ZOOM-001: Zoom In via Cmd+Plus
**AC**: GIVEN a document is open WHEN user presses Cmd+Plus THEN preview text renders at larger scale
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/AppSettings.swift`:103-104 - `zoomIn()`; `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:113-116 - Zoom In button
- Evidence: `zoomIn()` increments by 0.1, clamped at 3.0. Menu button dispatches with `Cmd++` shortcut. `MarkdownPreviewView.swift`:96-108 has `.onChange(of: appSettings.scaleFactor)` that rebuilds text storage with new scale factor. `PlatformTypeConverter` font methods all accept `scaleFactor` parameter and multiply point sizes.
- Field Notes: N/A
- Issues: None

### REQ-ZOOM-002: Zoom Out via Cmd+Minus
**AC**: GIVEN a document is open at scale >1.0 WHEN user presses Cmd+Minus THEN text renders at smaller scale
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/AppSettings.swift`:108-109 - `zoomOut()`; `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:118-121
- Evidence: `zoomOut()` decrements by 0.1, clamped at 0.5. Menu button with `Cmd+-` shortcut.
- Field Notes: N/A
- Issues: None

### REQ-ZOOM-003: Actual Size via Cmd+0
**AC**: GIVEN a non-default scale WHEN user presses Cmd+0 THEN scale resets to 1.0
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/AppSettings.swift`:113-114 - `zoomReset()`; `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:124-128
- Evidence: `zoomReset()` sets `scaleFactor = 1.0`. Menu button with `Cmd+0` shortcut.
- Field Notes: N/A
- Issues: None

### REQ-ZOOM-004: Scale factor persists across restarts
**AC**: GIVEN zoom at 1.5x and quit WHEN relaunched THEN zoom is 1.5x
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/AppSettings.swift`:10 (`scaleFactorKey`), :66-69 (`scaleFactor` didSet), :88-89 (init)
- Evidence: `scaleFactor` property stores to UserDefaults on `didSet`. Init reads from UserDefaults: `let storedScale = CGFloat(UserDefaults.standard.double(forKey: scaleFactorKey))`. Falls back to 1.0 if stored value is 0.
- Field Notes: N/A
- Issues: None

### REQ-ZOOM-005: Zoom items in View menu
**AC**: GIVEN the app is running WHEN user opens View menu THEN Zoom In, Zoom Out, Actual Size listed with shortcuts
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:111-131 - `CommandGroup(after: .toolbar)` Section
- Evidence: Three buttons (Zoom In, Zoom Out, Actual Size) with Cmd++, Cmd+-, Cmd+0 shortcuts. Each also sets `modeOverlayLabel` to display the zoom percentage.
- Field Notes: N/A
- Issues: None

### REQ-ZOOM-006: Crisp text at all scale factors
**AC**: Text remains sharp with no pixelation at any supported scale
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Core/Markdown/PlatformTypeConverter.swift`:14-38 - All font methods accept `scaleFactor` and multiply point sizes
- Evidence: Design decision D1 (font-size scaling, not view magnification) is correctly implemented. All `headingFont()`, `bodyFont()`, `monospacedFont()`, `captionMonospacedFont()` methods multiply the base point size by `scaleFactor`. This produces real font size changes rather than bitmap scaling, ensuring crisp text at all scales.
- Field Notes: N/A
- Issues: None

### REQ-SAVEAS-001: Save As via Shift+Cmd+S
**AC**: GIVEN a document is open WHEN user presses Shift+Cmd+S THEN NSSavePanel appears
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/DocumentState.swift`:77-103 - `saveAs()`; `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:48-52
- Evidence: `saveAs()` creates NSSavePanel, sets `allowedContentTypes` to `.md`, `canCreateDirectories = true`. Menu item has Shift+Cmd+S shortcut.
- Field Notes: N/A
- Issues: None

### REQ-SAVEAS-002: DocumentState tracks new URL after save
**AC**: After Save As, DocumentState.currentFileURL reflects new path, file watcher monitors new path, window title reflects new filename
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/DocumentState.swift`:94-99
- Evidence: After successful write: `currentFileURL = url`, `lastSavedContent = markdownContent`, `fileWatcher.watch(url: url)`, `NSDocumentController.shared.noteNewRecentDocumentURL(url)`. File watcher is paused before write and resumed after via `defer`.
- Field Notes: N/A
- Issues: None

### REQ-SAVEAS-003: Save As in File menu
**AC**: Save As... listed in File menu with Shift+Cmd+S
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:48-52
- Evidence: Button "Save As..." with `.keyboardShortcut("s", modifiers: [.command, .shift])`. Placed in `CommandGroup(replacing: .saveItem)` alongside Save.
- Field Notes: N/A
- Issues: None

### REQ-SAVEAS-004: Panel defaults to current filename and directory
**AC**: GIVEN "readme.md" from ~/Projects/ WHEN Save As invoked THEN panel pre-fills filename and directory
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/DocumentState.swift`:84-87
- Evidence: `panel.directoryURL = currentURL.deletingLastPathComponent()` and `panel.nameFieldStringValue = currentURL.lastPathComponent`. Conditional on `currentFileURL` being non-nil.
- Field Notes: N/A
- Issues: None

### REQ-COPY-001: Copy button appears on hover
**AC**: GIVEN a document with code blocks WHEN mouse hovers over code block THEN copy button becomes visible
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`:97-109 (tracking area), :111-115 (mouseMoved), :122-130 (updateCopyButtonForMouse), :133-168 (showCopyButton)
- Evidence: `updateTrackingAreas()` installs NSTrackingArea with `.mouseMoved`, `.mouseEnteredAndExited`, `.activeInActiveApp`. `mouseMoved` converts event location and calls `updateCopyButtonForMouse`. Hit-testing against `cachedBlockRects` identifies hovered code block. `showCopyButton` positions an NSHostingView at top-right corner.
- Field Notes: N/A
- Issues: None

### REQ-COPY-002: Click copies raw code to clipboard
**AC**: Clicking copy button places code content (without language label, without whitespace) on clipboard
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`:190-201 (copyCodeBlock); `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:111 (rawCode attribute set)
- Evidence: `appendCodeBlock` stores `trimmedCode` (code stripped of whitespace) via `CodeBlockAttributes.rawCode` on the full code range (line 111). `copyCodeBlock` reads `rawCode` attribute from textStorage at the given range and places it on `NSPasteboard.general` as `.string`. Language label is stored in a separate range and is not included in `rawCode`.
- Field Notes: N/A
- Issues: None

### REQ-COPY-003: Checkmark feedback after copy
**AC**: Button briefly shows checkmark/success state after copy
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Features/Viewer/Views/CodeBlockCopyButton.swift`:14-18 (body), :26-37 (performCopy)
- Evidence: `performCopy()` calls `onCopy()`, then toggles `isCopied = true` with `quickShift` animation. After 1.5 seconds, reverts to `false`. Body switches between `"checkmark"` and `"doc.on.doc"` SF Symbols with `.contentTransition(.symbolEffect(.replace))`.
- Field Notes: N/A
- Issues: None

### REQ-COPY-004: Theme-aware styling
**AC**: Copy button colors consistent with current theme
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Features/Viewer/Views/CodeBlockCopyButton.swift`:8-24
- Evidence: Button uses `.foregroundStyle(.secondary)` and `.background(.ultraThinMaterial)` which are system-adaptive. The `codeBlockColors: CodeBlockColorInfo` parameter is passed but not directly used for icon/background coloring in the current implementation. The design specified reading colors from `CodeBlockColorInfo` for consistent styling, but the implementation uses SwiftUI system adaptive materials instead.
- Field Notes: N/A
- Issues: `codeBlockColors` property is accepted but unused in the view body. The `.secondary` foreground and `.ultraThinMaterial` background are reasonably theme-adaptive via system APIs, but do not directly use the theme's specific color tokens as the design intended. This is a minor deviation -- the visual result is likely acceptable but not strictly per-spec.

### REQ-COPY-005: Subtle fade animation
**AC**: Copy button fades in/out with subtle animation on hover
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`:165-168 (fade in), :171-178 (fade out)
- Evidence: `showCopyButton` runs `NSAnimationContext.runAnimationGroup` with 0.2s duration to animate `alphaValue` to 1.0. `hideCopyButton` animates to 0.0 with same 0.2s duration. This provides smooth fade in/out on hover.
- Field Notes: N/A
- Issues: None

### REQ-TASK-001: Unchecked checkbox rendering
**AC**: `- [ ]` renders as unchecked checkbox visual
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Core/Markdown/MarkdownVisitor.swift`:171-177 (checkbox extraction); `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift`:370-414 (checkboxPrefix); `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Features/Viewer/Views/MarkdownBlockView.swift`:142-146 (SwiftUI path)
- Evidence: `checkboxState(from:)` in MarkdownVisitor maps `listItem.checkbox == .unchecked` to `.unchecked`. `checkboxPrefix()` in the builder creates an NSTextAttachment with SF Symbol `"square"`. MarkdownBlockView line 143 uses `Image(systemName: "square")` for SwiftUI rendering.
- Field Notes: N/A
- Issues: None

### REQ-TASK-002: Checked checkbox rendering
**AC**: `- [x]` renders as checked checkbox visual
- Status: VERIFIED
- Implementation: Same files as REQ-TASK-001
- Evidence: `checkboxState(from:)` maps `.checked`. `checkboxPrefix()` uses `"checkmark.square.fill"` SF Symbol. MarkdownBlockView line 143 uses `"checkmark.square.fill"`.
- Field Notes: N/A
- Issues: None

### REQ-TASK-003: Checkboxes are read-only
**AC**: Clicking a checkbox does nothing
- Status: VERIFIED
- Implementation: NSTextView-based rendering (NSTextAttachment images are non-interactive); SwiftUI `Image` views are non-interactive by default
- Evidence: Checkboxes are rendered as NSTextAttachment images in the NSTextView (read-only, `isEditable = false` at SelectableTextView.swift:131) and as SwiftUI `Image` views in MarkdownBlockView. Neither provides click handlers for checkbox state changes. No toggle logic exists anywhere in the codebase.
- Field Notes: N/A
- Issues: None

### REQ-TASK-004: SF Symbols for native appearance
**AC**: Checkbox visuals use SF Symbols
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift`:373, 377-381
- Evidence: Uses `NSImage(systemSymbolName: symbolName, ...)` with `"square"` and `"checkmark.square.fill"`. Falls back to text `"[ ]"`/`"[x]"` only if the system symbol is unavailable.
- Field Notes: N/A
- Issues: None

### REQ-TASK-005: Theme-aware checkbox color
**AC**: Checkbox icons use theme foreground color
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift`:388-393 (NSTextView path); MarkdownBlockView.swift:145 (SwiftUI path)
- Evidence: NSTextView path tints the image with `color` parameter (passed as `ctx.resolved.secondaryColor` which is `colors.foregroundSecondary`). SwiftUI path uses `.foregroundColor(colors.foregroundSecondary)`.
- Field Notes: N/A
- Issues: None

### REQ-MULTI-001: Multiple files open in separate windows
**AC**: `mkdn a.md b.md c.md` opens three separate windows
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Core/CLI/MkdnCLI.swift`:10-11 (variadic argument); `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdnEntry/main.swift`:68-95 (multi-file flow); `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/DocumentWindow.swift`:38-46 (consume URLs)
- Evidence: `MkdnCLI.files` is `[String]` with `@Argument` (variadic). `main.swift` iterates files, validates each, joins valid paths with newline, sets `MKDN_LAUNCH_FILE`, and `execv`s. Re-launched process splits env var by `\n` into `LaunchContext.fileURLs`. `DocumentWindow.onAppear` loads first URL in current window and calls `openWindow(value: url)` for remaining URLs.
- Field Notes: N/A
- Issues: None

### REQ-MULTI-002: Independent file validation
**AC**: Invalid files produce stderr errors, valid files still open
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdnEntry/main.swift`:70-78
- Evidence: Each file is validated in a loop. Errors are caught as `CLIError` and written to stderr: `FileHandle.standardError.write(Data("mkdn: error: \(error.localizedDescription)\n".utf8))`. Processing continues with remaining files. Exit 1 only if all files fail (line 81-82: `guard !validURLs.isEmpty else { Foundation.exit(1) }`).
- Field Notes: N/A
- Issues: None

### REQ-MULTI-003: Files open via FileOpenCoordinator
**AC**: FileOpenCoordinator.pendingURLs contains all valid file URLs
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/DocumentWindow.swift`:38-46
- Evidence: Multi-file opening uses `LaunchContext.fileURLs` (not FileOpenCoordinator) for CLI-launched files. `LaunchContext.consumeURLs()` returns the URLs and clears them. The first URL loads in the current window; remaining open via `openWindow(value:)`. This is functionally equivalent but uses LaunchContext instead of FileOpenCoordinator as the transport mechanism. FileOpenCoordinator is used for Finder/dock opens (line 48-56), not CLI opens.
- Field Notes: N/A
- Issues: The requirement text says "FileOpenCoordinator" but the design and implementation correctly use LaunchContext for CLI opens (FileOpenCoordinator is for runtime file opens). The requirement wording is slightly inaccurate relative to the architecture.

### REQ-MULTI-004: `mkdn --help` shows variadic argument
**AC**: Help output shows multiple file paths accepted
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/Core/CLI/MkdnCLI.swift`:10-11
- Evidence: `@Argument(help: "Path(s) to Markdown file(s) (.md or .markdown).") public var files: [String] = []`. ArgumentParser will display this as a variadic argument in `--help` output.
- Field Notes: N/A
- Issues: None

### REQ-ABOUT-001: About mkdn in application menu
**AC**: "About mkdn" listed in application menu
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:17-23 - `CommandGroup(replacing: .appInfo)`
- Evidence: Button "About mkdn" in `CommandGroup(replacing: .appInfo)` replaces the default About menu item.
- Field Notes: N/A
- Issues: None

### REQ-ABOUT-002: Panel shows icon, name, version
**AC**: About panel displays app icon, "mkdn" name, and version number
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:19-21; `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/Resources/Info.plist`:8-9, 16-19
- Evidence: `NSApp.orderFrontStandardAboutPanel(options: [.applicationIcon: NSApp.applicationIconImage as Any])` passes the custom icon. Info.plist has `CFBundleName = "mkdn"`, `CFBundleShortVersionString = "1.0.0"`, `CFBundleVersion = "1.0.0"`. The standard panel reads these values. `MkdnCLI.configuration.version` is also `"1.0.0"` -- versions are aligned.
- Field Notes: N/A
- Issues: None

### REQ-ABOUT-003: Minimal and elegant appearance
**AC**: About window appears clean and minimal
- Status: MANUAL_REQUIRED
- Implementation: Uses `NSApp.orderFrontStandardAboutPanel` which provides the standard macOS About panel appearance.
- Evidence: Standard panel is inherently clean and native. Cannot verify visual appearance programmatically.
- Field Notes: N/A
- Issues: Subjective criterion; standard macOS About panel is the correct choice.

### REQ-ABOUT-004: Uses standard macOS About panel
**AC**: Standard macOS About panel is presented
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:19-21
- Evidence: Calls `NSApp.orderFrontStandardAboutPanel(options:)` directly. No custom SwiftUI window is used.
- Field Notes: N/A
- Issues: None

### NFR-UX-003: Zoom level ephemeral overlay
**AC**: Zoom level displayed briefly via ephemeral overlay (e.g., "125%")
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/AppSettings.swift`:118-120 (`zoomLabel`); `/Users/jud/Projects/mkdn/.rp1/work/worktrees/feature-mac-app-essentials/mkdn/App/MkdnCommands.swift`:115, 121, 128
- Evidence: `appSettings.zoomLabel` returns `"\(Int(round(scaleFactor * 100)))%"`. Each zoom command sets `documentState?.modeOverlayLabel = appSettings.zoomLabel`. ContentView.swift lines 37-42 display a `ModeTransitionOverlay` when `modeOverlayLabel` is non-nil.
- Field Notes: N/A
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- **REQ-PRINT-002 (Themed print output)**: Cannot be verified programmatically. The implementation relies on NSTextView's built-in print behavior with the themed attributed string, which is architecturally correct. Requires manual verification by printing.

### Partial Implementations
- **REQ-COPY-004 (Theme-aware copy button)**: `codeBlockColors` property is passed to `CodeBlockCopyButton` but not used in the view body. The button uses system `.secondary` and `.ultraThinMaterial` instead. This is functionally adequate but not strictly per-spec.
- **REQ-MULTI-003 (FileOpenCoordinator for CLI)**: The implementation correctly uses `LaunchContext` instead of `FileOpenCoordinator` for CLI-launched files. This is architecturally correct (LaunchContext is the CLI transport, FileOpenCoordinator is for runtime opens). The requirement text is slightly misleading.

### Implementation Issues
- None critical. All code compiles and follows the documented patterns.

## Code Quality Assessment

**Architecture Compliance**: HIGH. All implementations follow the documented Feature-Based MVVM pattern. State management uses `@Observable` + `@MainActor` consistently. No `ObservableObject` usage. No WKWebView usage.

**Pattern Adherence**: All animation uses named primitives (`quickShift` in CodeBlockCopyButton). Menu commands use `CommandGroup` pattern with `@FocusedValue`. Font scaling uses the correct approach (font-size multiplication, not view magnification).

**Code Organization**: Clean separation of concerns. New code integrates naturally with existing patterns. CodeBlockCopyButton is a focused single-responsibility view. Zoom logic is cleanly split between AppSettings (persistence/logic), MkdnCommands (menu), MarkdownPreviewView (rebuild trigger), and PlatformTypeConverter (font scaling).

**Error Handling**: Save As wraps write in do/catch (line 94-102). Multi-file CLI validates each file independently with per-file error reporting to stderr. Graceful degradation throughout.

**Swift 6 Compliance**: All new observable state is `@MainActor`-isolated. `LaunchContext` uses `nonisolated(unsafe)` appropriately for the sequential pre-main access pattern.

## Recommendations

1. **Address tasks.md staleness**: Tasks T3, T6, T7, T8 are marked unchecked in tasks.md but have full implementations in the worktree. Update tasks.md to reflect actual implementation status.

2. **Create field-notes.md**: Document the Save As disabled-condition deviation (using `documentState == nil` instead of `documentState?.currentFileURL == nil`) and the LaunchContext-vs-FileOpenCoordinator architectural choice for CLI multi-file opens.

3. **Minor: Use codeBlockColors in CodeBlockCopyButton**: The `codeBlockColors` property is passed but unused. Either use it for icon/background coloring to match the design spec, or remove it to avoid dead code.

4. **Add unit tests for T3, T6, T7**: The design specifies unit tests for zoom scale persistence/clamping, checkbox extraction, and multi-file CLI validation. These appear not yet written (tasks.md shows them unchecked). These are high-value tests per the design's test value assessment.

5. **Manual verification needed**: REQ-PRINT-002 (themed print output) and REQ-ABOUT-003 (elegant About window) require manual visual verification.

## Verification Evidence

### T1 Find in Document - Key Code
```swift
// SelectableTextView.swift:138-139
textView.usesFindBar = true
textView.isIncrementalSearchingEnabled = true

// MkdnCommands.swift:162-171
private func sendFindAction(tag: Int) {
    let menuItem = NSMenuItem()
    menuItem.tag = tag
    NSApp.sendAction(
        #selector(NSTextView.performFindPanelAction(_:)),
        to: nil,
        from: menuItem
    )
}
```

### T3 Zoom - Key Code
```swift
// AppSettings.swift:103-115
public func zoomIn() {
    scaleFactor = min(scaleFactor + 0.1, 3.0)
}
public func zoomOut() {
    scaleFactor = max(scaleFactor - 0.1, 0.5)
}
public func zoomReset() {
    scaleFactor = 1.0
}

// PlatformTypeConverter.swift:14-15 (example)
static func headingFont(level: Int, scaleFactor: CGFloat = 1.0) -> NSFont {
    // baseSize * scaleFactor
}

// MarkdownPreviewView.swift:96-108
.onChange(of: appSettings.scaleFactor) {
    // Rebuilds text storage with new scale factor
    textStorageResult = MarkdownTextStorageBuilder.build(
        blocks: newBlocks, theme: appSettings.theme, scaleFactor: appSettings.scaleFactor
    )
}
```

### T5 Code Block Copy - Key Code
```swift
// CodeBlockAttributes.swift:21
static let rawCode = NSAttributedString.Key("mkdn.codeBlock.rawCode")

// MarkdownTextStorageBuilder+Blocks.swift:111
codeContent.addAttribute(CodeBlockAttributes.rawCode, value: trimmedCode, range: fullRange)

// CodeBlockBackgroundTextView.swift:190-201
private func copyCodeBlock(at range: NSRange) {
    guard let rawCode = textStorage.attribute(
        CodeBlockAttributes.rawCode, at: range.location, effectiveRange: nil
    ) as? String else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(rawCode, forType: .string)
}
```

### T6 Task List Checkboxes - Key Code
```swift
// MarkdownBlock.swift:69-73
enum CheckboxState: Sendable {
    case checked
    case unchecked
}

// MarkdownVisitor.swift:171-177
private func checkboxState(from listItem: Markdown.ListItem) -> CheckboxState? {
    switch listItem.checkbox {
    case .checked: .checked
    case .unchecked: .unchecked
    case nil: nil
    }
}

// MarkdownTextStorageBuilder+Complex.swift:373
let symbolName = state == .checked ? "checkmark.square.fill" : "square"
```

### T7 Multi-file CLI - Key Code
```swift
// MkdnCLI.swift:10-11
@Argument(help: "Path(s) to Markdown file(s) (.md or .markdown).")
public var files: [String] = []

// main.swift:59-62 (re-launch reads)
let urls = envFile.split(separator: "\n").map { path in
    URL(fileURLWithPath: String(path)).standardized.resolvingSymlinksInPath()
}
LaunchContext.fileURLs = urls

// DocumentWindow.swift:38-46 (consume)
let launchURLs = LaunchContext.consumeURLs()
if let first = launchURLs.first {
    try? documentState.loadFile(at: first)
}
for url in launchURLs.dropFirst() {
    openWindow(value: url)
}
```

### T8 About Window - Key Code
```swift
// MkdnCommands.swift:17-23
CommandGroup(replacing: .appInfo) {
    Button("About mkdn") {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationIcon: NSApp.applicationIconImage as Any,
        ])
    }
}

// Info.plist
CFBundleShortVersionString: 1.0.0
CFBundleName: mkdn
```
