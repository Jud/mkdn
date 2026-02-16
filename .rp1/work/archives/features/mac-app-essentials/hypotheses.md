# Hypothesis Document: mac-app-essentials
**Version**: 1.0.0 | **Created**: 2026-02-13T00:00:00Z | **Status**: VALIDATED

## Hypotheses
### HYP-001: NSTextView Find Bar with TextKit 2
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: NSTextView's built-in find bar (usesFindBar = true) works correctly with the TextKit 2 configuration used by SelectableTextView/CodeBlockBackgroundTextView in the mkdn codebase.
**Context**: The mkdn app uses a TextKit 2 NSTextView (NSTextLayoutManager + NSTextContentStorage) for its preview pane. Adding Cmd+F find functionality requires the find bar to work with this specific TextKit 2 setup.
**Validation Criteria**:
- CONFIRM if: Enable usesFindBar and isIncrementalSearchingEnabled on the CodeBlockBackgroundTextView. Invoke performFindPanelAction with tag 1 (showFindPanel). The find bar appears, accepts text input, highlights matches in the attributed string, and Find Next/Previous navigate correctly.
- REJECT if: The find bar does not appear, crashes, or fails to find/highlight text in the TextKit 2 NSTextView.
**Suggested Method**: CODE_EXPERIMENT

### HYP-002: Mouse Tracking and Copy Button Overlay on TextKit 2 Code Blocks
**Risk Level**: MEDIUM
**Status**: CONFIRMED
**Statement**: Mouse tracking and copy button overlay positioning works reliably on CodeBlockBackgroundTextView using TextKit 2 fragment geometry.
**Context**: The mkdn app uses TextKit 2 (NSTextLayoutManager) throughout. The CodeBlockBackgroundTextView already does geometry-based drawing for code block backgrounds using fragment rects. Adding a copy button overlay on hover requires accurate mouse-to-code-block mapping and overlay positioning.
**Validation Criteria**:
- CONFIRM if: Install NSTrackingArea on CodeBlockBackgroundTextView with mouseMoved. On mouse move, collectCodeBlocks + fragmentFrames correctly identifies which code block the cursor is over. An NSHostingView positioned at the top-right of the code block bounding rect appears correctly and responds to clicks.
- REJECT if: Mouse position does not accurately map to code block geometry, or the NSHostingView overlay interferes with NSTextView text selection, or the overlay position is incorrect during scrolling.
**Suggested Method**: CODEBASE_ANALYSIS

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-13T22:47:00Z
**Method**: CODE_EXPERIMENT + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

Three code experiments were run, each creating a TextKit 2 NSTextView stack identical to mkdn's configuration (NSTextContainer + NSTextLayoutManager + NSTextContentStorage + NSTextView(frame:textContainer:)), with `isEditable = false` and `isSelectable = true`.

1. **TextKit 2 persists after find bar enablement**: Setting `usesFindBar = true` and `isIncrementalSearchingEnabled = true` does NOT cause TextKit 2 to fall back to TextKit 1. `textView.textLayoutManager` remains non-nil throughout. This is the key risk that was mitigated -- some NSTextView operations trigger automatic fallback to TextKit 1, but the find bar does not.

2. **Find bar appears correctly**: `performFindPanelAction(_:)` with tag 1 (showFindPanel) causes the find bar to appear. Verified via `NSTextFinderBarContainer.isFindBarVisible == true` and `findBarView != nil` on the enclosing NSScrollView.

3. **Text content is accessible for search**: `NSTextView.string` returns the full text content (verified 335 characters). The NSTextView responds to all critical NSTextFinderClient selectors: `string`, `firstSelectedRange`, `scrollRangeToVisible:`, `contentViewAtIndex:effectiveCharacterRange:`, `rectsForCharacterRange:`, `visibleCharacterRanges`, `drawCharactersInRange:forContentView:`.

4. **Find actions dispatch correctly**: Tags 1 (show), 2 (next), 3 (previous), 7 (setFindString) all execute without crash. "Use Selection for Find" (tag 7) correctly sets the find string from the current selection.

5. **Non-editable text views supported**: The find bar works with `isEditable = false`. The Replace UI is automatically hidden for non-editable views, showing only the Find interface -- which is the correct behavior for mkdn's read-only preview pane.

6. **Known caveat (minor)**: When the find bar is dismissed (Esc or Done), focus does not automatically return to the text view. This is a long-standing NSTextView/NSTextFinder behavior. Workaround: observe `NSScrollView.isFindBarVisible` via KVO and call `window.makeFirstResponder(textView)` when it becomes false.

7. **Swift protocol conformance note**: `textView is NSTextFinderClient` returns `false` in Swift for both TextKit 1 and TextKit 2 NSTextViews. This is a Swift bridging artifact, not an actual compatibility issue. NSTextView implements the required Objective-C methods internally. The `responds(to:)` checks confirm the implementation is present.

**Sources**:
- Code experiment: `/tmp/hypothesis-mac-app-essentials/FindBarTest.swift` (DISPOSABLE)
- Code experiment: `/tmp/hypothesis-mac-app-essentials/FindBarTest2.swift` (DISPOSABLE)
- Code experiment: `/tmp/hypothesis-mac-app-essentials/FindBarTest3.swift` (DISPOSABLE)
- https://developer.apple.com/documentation/appkit/nstextview/usesfindbar
- https://developer.apple.com/documentation/appkit/nstextfinder
- https://christiantietze.de/posts/2018/02/nstextview-find-bar-disappear/ (find bar focus restoration caveat)
- https://developer.apple.com/videos/play/wwdc2022/10090/ (TextKit 2 adoption, macOS Ventura defaults)

**Implications for Design**:
The design's approach of enabling `usesFindBar = true` and `isIncrementalSearchingEnabled = true` in `SelectableTextView.configureTextView()` and dispatching via `NSApp.sendAction(performFindPanelAction:)` is correct and will work as specified. No TextKit 2 compatibility issues. Consider adding KVO on `isFindBarVisible` to restore focus when the find bar is dismissed (optional polish).

---

### HYP-002 Findings
**Validated**: 2026-02-13T22:47:00Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS
**Result**: CONFIRMED

**Evidence**:

A code experiment created a TextKit 2 NSTextView subclass with `updateTrackingAreas()` and `mouseMoved(with:)` overrides, plus analysis of existing patterns in the mkdn codebase.

1. **NSTrackingArea installs correctly on TextKit 2 NSTextView**: `updateTrackingAreas()` is called automatically by AppKit. The tracking area with options `[.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp]` installs successfully. Two tracking areas are present after installation (the custom one plus NSTextView's own cursor tracking area).

2. **TextKit 2 fragment geometry accurately maps code block bounds**: Using the same `enumerateTextLayoutFragments(from:options:)` pattern already used in `CodeBlockBackgroundTextView.fragmentFrames()`, the code block's layout fragments were enumerated. The bounding rect (`frames.reduce(frames[0]) { $0.union($1) }`) correctly identifies the code block region. Test output: 3 fragments for a 3-line code block, with a union bounding rect of `(5.0, 68.0, 104.0, 51.0)`.

3. **Mouse position maps to code block geometry**: Converting the mouse event's `locationInWindow` via `convert(_:from: nil)` and subtracting `textContainerOrigin` yields text-coordinate-space points that correctly hit-test against the bounding rect. Points inside the code block return `true`, points outside return `false`. This is the same coordinate system used in `drawCodeBlockContainers(in:)`.

4. **NSHostingView overlay works as subview of NSTextView**: Adding an NSHostingView via `textView.addSubview(button)` works correctly. The overlay appears at the specified frame position. This is the IDENTICAL pattern already used by `OverlayCoordinator` for Mermaid, image, table, and thematic break overlays (see `OverlayCoordinator.swift:253`).

5. **Overlay does NOT interfere with text selection**: With the NSHostingView overlay present, `textView.setSelectedRange(NSRange(location: 0, length: 10))` correctly selects text, returning "This is pa". NSTextView's text selection operates on the text layer, not the subview layer, so overlay subviews do not interfere. This is consistent with the existing behavior of Mermaid/table overlays in the codebase.

6. **Overlay scrolls with document automatically**: Because the overlay is a subview of the textView (which is the `documentView` of the NSScrollView), it scrolls with the document content automatically. No manual scroll offset tracking is needed. The existing `OverlayCoordinator` relies on this same behavior.

7. **Existing codebase patterns validate the approach**:
   - `CodeBlockBackgroundTextView.swift:144-171` -- `collectCodeBlocks(from:)` extracts code block ranges and colors from textStorage attributes. Currently `private` but can be made `fileprivate` or refactored for reuse.
   - `CodeBlockBackgroundTextView.swift:175-202` -- `fragmentFrames(for:layoutManager:contentManager:)` computes fragment geometry. Same visibility consideration.
   - `CodeBlockBackgroundTextView.swift:95-120` -- `drawCodeBlockContainers(in:)` already computes the bounding rect and textContainerOrigin offset. The copy button positioning uses the identical calculation.
   - `OverlayCoordinator.swift:253,275,327,469-470` -- Proven pattern of adding NSHostingView subviews to the NSTextView, including creating them lazily and showing/hiding based on state.
   - `CodeBlockBackgroundTextView.swift:41-77` -- `resetCursorRects()` already uses `fragmentFrames()` to compute geometry for link cursor rects, proving the geometry pipeline works for interactive purposes (not just drawing).

**Sources**:
- Code experiment: `/tmp/hypothesis-mac-app-essentials/MouseTrackingTest.swift` (DISPOSABLE)
- Codebase: `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift:41-77` (cursor rects using fragment geometry)
- Codebase: `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift:86-121` (code block bounding rect calculation)
- Codebase: `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift:144-202` (collectCodeBlocks + fragmentFrames)
- Codebase: `mkdn/Features/Viewer/Views/OverlayCoordinator.swift:253` (textView.addSubview for NSHostingView)
- Codebase: `mkdn/Features/Viewer/Views/OverlayCoordinator.swift:416-498` (scroll observation + sticky header overlay pattern)
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/TrackingAreaObjects/TrackingAreaObjects.html

**Implications for Design**:
The design's approach of overriding `updateTrackingAreas()` and `mouseMoved(with:)` in CodeBlockBackgroundTextView is correct. The existing `collectCodeBlocks` and `fragmentFrames` methods provide the exact geometry needed for hit-testing. A single lazily-created NSHostingView can be shown/hidden and repositioned on each mouse move. The `textContainerOrigin` offset must be applied consistently (matching the pattern in `drawCodeBlockContainers`). The `collectCodeBlocks` and `fragmentFrames` methods will need their access level changed from `private` to accessible from the mouse tracking methods (since they are in the same class, `private` already works -- no change needed). The only consideration is performance: `collectCodeBlocks` enumerates the full textStorage on every mouse move. For large documents, caching the block geometries and invalidating on content change would be worthwhile.

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001: Find Bar + TextKit 2 | HIGH | CONFIRMED | Enable usesFindBar + isIncrementalSearchingEnabled; dispatch via performFindPanelAction. No TextKit 2 compatibility issues. |
| HYP-002: Mouse Tracking + Copy Overlay | MEDIUM | CONFIRMED | NSTrackingArea + fragmentFrames geometry + NSHostingView overlay all work with TextKit 2. Existing codebase patterns (OverlayCoordinator, cursor rects) prove the approach. |
