### T4: TableAttachmentViewProvider + pipeline switchover
**Date:** 2026-03-24
**Status:** complete
**Files changed:**
- `mkdn/Core/Markdown/TableAttachmentData.swift` — restored `allowsTextAttachmentView = true` in designated init, removed dead `viewProvider(for:)` override
- `mkdn/Core/Markdown/TableAttachmentViewProvider.swift` — DELETED: `NSTextAttachmentViewProvider` is fundamentally incompatible with Swift 6 strict concurrency (TextKit 2 never calls `loadView()` on the provider because the nonisolated override doesn't dispatch correctly under strict concurrency)
- `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` — no change from previous round (table dispatch already correct)
- `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift` — updated doc comment to reflect overlay approach; `appendTableAttachment` signature unchanged
- `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` — `.table` in `needsOverlay()` and `createAttachmentOverlay()` (restored from previous round)
- `mkdn/Features/Viewer/Views/OverlayCoordinator+Factories.swift` — `makeTableAttachmentOverlay()` now uses `NSHostingView` (not `PassthroughHostingView`), enabling mouse events for cell selection/copy
- `mkdn/Features/Viewer/Views/TableAttachmentView.swift` — `onCopyCommand` returns proper `[NSItemProvider]` instead of writing to pasteboard as side effect; added `UniformTypeIdentifiers` import
- `mkdnTests/Unit/Core/MarkdownTextStorageBuilderTableTests.swift` — tests verify attachment-based pipeline via `result.attachments`

**Notes:**
- **NSTextAttachmentViewProvider cannot work under Swift 6 strict concurrency.** Exhaustive investigation confirmed: TextKit 2 calls `viewProvider(for:location:textContainer:)` on `TableTextAttachment` (verified via NSLog), returns a `TableAttachmentViewProvider` instance, but never calls `loadView()` on it. The root cause: `NSTextAttachmentViewProvider` methods are nonisolated in the SDK, but creating SwiftUI views (`TableAttachmentView`, `NSHostingView`, `AppSettings`) requires `@MainActor`. Under Swift 6 strict concurrency, no annotation combination (`@preconcurrency @MainActor`, `@unchecked Sendable`, `nonisolated(unsafe)`, container view pattern) results in TextKit 2 successfully invoking `loadView()` and using the returned view. The file has been deleted as dead code.
- **Overlay approach is correct and consistent.** Tables use the same `NSTextAttachment` placeholder + `OverlayCoordinator` pattern as Mermaid, image, math, and thematic break blocks. This is architecturally sound and well-tested.
- **Critical fix: `NSHostingView` replaces `PassthroughHostingView`.** The old `PassthroughHostingView` returned `nil` from `hitTest()`, blocking all mouse events. `TableAttachmentView` handles selection itself via SwiftUI gestures (`onTapGesture` with modifier key detection), so it must receive mouse events. Using `NSHostingView` directly enables click, Cmd+click, Shift+click, and `onCopyCommand`.
- **`onCopyCommand` returns proper `NSItemProvider`.** Instead of writing to the pasteboard as a side effect and returning `[]`, now returns `[NSItemProvider(item: text as NSString, typeIdentifier: UTType.utf8PlainText.identifier)]`. This is the correct contract for `onCopyCommand`.
- **`allowsTextAttachmentView = true` restored** in the designated init for defensive coding and test clarity.

**Baseline (before changes):**
```
swift build: Build complete! (1.25s)
swift test: 708 tests in 65 suites passed (1.047s)
swiftlint: 4 pre-existing errors (MermaidTemplateLoader, SelectableTextView+Coordinator)
```

**Post-change (after changes):**
```
swift build: Build complete! (5.63s)
swift test: 708 tests in 65 suites passed (0.937s)
swiftlint: 0 violations in 8 changed files
swiftformat: 0 files need formatting
Visual verification: tables render correctly in both solarizedLight and solarizedDark themes, with correct borders, headers, zebra striping, alignment, and spacing
```
