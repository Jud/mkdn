# Quick Build: Add Link Navigation

**Created**: 2026-02-21T00:00:00Z
**Request**: Add link navigation feature for markdown viewer. Local markdown file links (relative paths resolved relative to current document location) open in same window on click. Cmd+click opens in new window with same sidebar settings. Non-markdown links (http/https, non-.md files) open in default browser. Links already render as clickable -- need to intercept clicks and handle navigation.
**Scope**: Medium

## Plan

**Reasoning**: This feature touches 3-4 files in 1-2 systems (Viewer + App layer). The NSTextView already renders links with `.link` attributes set by MarkdownTextStorageBuilder. The key work is intercepting link clicks via NSTextViewDelegate (textView(_:clickedOnLink:at:)) in the Coordinator, resolving URLs relative to the current document, and routing to the appropriate handler. Risk is medium due to NSTextView delegate subtleties with Cmd-click detection and ensuring the text view delegate doesn't break existing selection behavior.

**Files Affected**:
- `mkdn/Features/Viewer/Views/SelectableTextView.swift` -- Add NSTextViewDelegate to Coordinator for link click interception
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` -- Override `clicked(onLink:at:)` or set delegate on the text view
- `mkdn/App/DocumentState.swift` -- Add method to navigate to a local markdown file (same-window)
- `mkdn/Core/Markdown/LinkNavigationHandler.swift` (new) -- URL resolution and routing logic

**Approach**: The NSTextView already has `.link` attributes on inline links from MarkdownTextStorageBuilder.convertInlineContent(). By default NSTextView opens links in the browser. We intercept this by making the Coordinator conform to NSTextViewDelegate and implementing `textView(_:clickedOnLink:at:)`. The handler will: (1) check if Cmd is held via NSEvent.modifierFlags, (2) resolve the URL relative to the current document's directory, (3) for local .md/.markdown files: load in same window (click) or open new window (Cmd+click), (4) for all other URLs: open in default browser via NSWorkspace. The Coordinator already has access to documentState for same-window navigation, and we pass openWindow for new-window support.

**Estimated Effort**: 3-4 hours

## Tasks

- [x] **T1**: Create `LinkNavigationHandler` enum in `mkdn/Core/Markdown/` with static methods to classify a URL (local markdown, external, other local file) and resolve relative paths against a document base URL `[complexity:simple]`
- [x] **T2**: Wire NSTextViewDelegate on SelectableTextView.Coordinator, set `textView.delegate = coordinator` in makeNSView, implement `textView(_:clickedOnLink:at:)` to intercept all link clicks and route through LinkNavigationHandler `[complexity:medium]`
- [x] **T3**: Implement same-window navigation for local markdown links by calling `documentState.loadFile(at:)` with the resolved URL, and new-window navigation (Cmd+click) via `openWindow(value: LaunchItem.file(url))` -- pass openWindow closure into Coordinator `[complexity:medium]`
- [x] **T4**: Implement external URL handling (http/https and non-markdown local files) via `NSWorkspace.shared.open(url)` to open in default browser/app `[complexity:simple]`
- [x] **T5**: Add unit tests for LinkNavigationHandler URL classification and relative path resolution logic `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Core/Markdown/LinkNavigationHandler.swift` | New enum with `LinkDestination` classification and `resolveRelativeURL` for path resolution against document base URL | Done |
| T2 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | Added `NSTextViewDelegate` conformance to Coordinator, set `textView.delegate = coordinator` in makeNSView, implemented `textView(_:clickedOnLink:at:)` | Done |
| T3 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | Same-window via `documentState.loadFile(at:)`, new-window (Cmd+click) via `FileOpenCoordinator.shared.pendingURLs` (uses existing infrastructure instead of threading openWindow) | Done |
| T4 | `mkdn/Features/Viewer/Views/SelectableTextView.swift` | External and non-markdown local files opened via `NSWorkspace.shared.open(url)` | Done |
| T5 | `mkdnTests/Unit/Core/LinkNavigationHandlerTests.swift` | 18 tests covering external URL classification (http, https, mailto, tel, unknown scheme), local markdown resolution (relative, subdirectory, file://), other local files, path traversal, anchor-only links | Done |

**Deviation from plan**: T3 uses `FileOpenCoordinator.shared.pendingURLs` for Cmd+click new-window navigation instead of threading `openWindow` through the view hierarchy. This leverages the existing AppKit-to-SwiftUI bridging pattern already used by `AppDelegate` for Finder file opens, avoiding unnecessary modifications to `MarkdownPreviewView`. `CodeBlockBackgroundTextView` and `DocumentState` did not need modification -- the delegate is set on the NSTextView (which CodeBlockBackgroundTextView inherits from), and `DocumentState.loadFile(at:)` already handles same-window navigation.

## Verification

{To be added by task-reviewer if --review flag used}
