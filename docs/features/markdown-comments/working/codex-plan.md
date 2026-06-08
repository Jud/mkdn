**Recommendation**

Use a hybrid: implement **S1 honest viewport resize** with a 60Hz managed resize driver and character-anchored scroll preservation, and treat **S2 reading column** as the product decision required for truly “pure movement” with zero reflow. Reject S3.

The reason is in the current code: the preview text container tracks the text view width, the text view autoresizes by width, has 32pt insets, and horizontal resizing is disabled, so narrowing the preview necessarily rewraps full-width text (`mkdn/Features/Viewer/Views/SelectableTextView.swift:157`, `:169`, `:192`, `:194`). With the default 800pt window and a 300pt sidebar, the remaining viewport is about 500pt (`mkdn/App/AppSettings.swift:114-118`, `mkdn/Features/Viewer/Views/CommentSidebarView.swift:39`). That means S1 can remove the vertical jump, but it cannot remove horizontal reflow. True zero-reflow at default size would require a reading column no wider than the narrowed content area, which is a visible product choice.

S3 should not be used: it avoids per-frame TextKit cost by delaying the real rewrap, but the final rewrap would still snap, which violates the stated requirement.

**1. Strategy**

Implement **S1 with two additions**:

- A local `sidebarProgress` value in `MarkdownPreviewView` drives preview width from `fullWidth` to `fullWidth - CommentSidebarView.width`.
- `SelectableTextView` gets a managed sidebar-resize path that captures a top-of-viewport text anchor, forces TextKit 2 viewport layout every tick, restores the anchor every tick, and repositions overlays.

This matches existing shipped width-change patterns: the directory sidebar already narrows and offsets `ContentView` during sidebar animation (`mkdn/App/DocumentWindow.swift:60-100`), and split mode continuously changes pane widths during divider drag (`mkdn/Features/Editor/Views/ResizableSplitView.swift:56-72`). But those do not prove 60fps for large documents; this implementation must be measured.

**2. View Tree Changes**

Keep the resize inside `MarkdownPreviewView`, not hoisted. That view owns the rendered comments, active/detached sidebar items, and `jumpToComment` callback (`mkdn/Features/Viewer/Views/MarkdownPreviewView.swift:61-80`, `:164-181`). Hoisting would require lifting private preview/comment state through `ContentView`.

Replace the current sidebar overlay path:

- Toggle overlay is currently at `MarkdownPreviewView.swift:87-99`.
- Sidebar overlay is currently at `MarkdownPreviewView.swift:100-115`.
- The whole overlay animation is currently tied to `isCommentSidebarVisible` at `MarkdownPreviewView.swift:116`.

New structure:

```swift
GeometryReader { proxy in
    let canShow = documentState.canShowCommentSidebar
    let railWidth = canShow ? CommentSidebarView.width * sidebarProgress : 0

    HStack(spacing: 0) {
        previewTextView
            .frame(width: max(proxy.size.width - railWidth, 0))

        if canShow && (sidebarProgress > 0 || documentState.isCommentSidebarVisible) {
            CommentSidebarView(...)
                .frame(width: CommentSidebarView.width)
                .offset(x: CommentSidebarView.width * (1 - sidebarProgress))
                .allowsHitTesting(sidebarProgress == 1)
                .accessibilityHidden(sidebarProgress == 0)
        }
    }
    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
    .clipped()
    .overlay(alignment: .topTrailing) { closedSidebarToggle }
}
```

Preserve preview-only gating through `DocumentState.canShowCommentSidebar`, which is already restricted to loaded markdown in preview-only mode (`mkdn/App/DocumentState.swift:78-83`). `ContentView` mounts `MarkdownPreviewView` in preview-only mode (`mkdn/App/ContentView.swift:36-39`), while `SplitEditorView` also uses `MarkdownPreviewView` as the right pane (`mkdn/Features/Editor/Views/SplitEditorView.swift:10-14`), so the existing gate remains necessary.

Drive `sidebarProgress` from `onChange(of: documentState.isCommentSidebarVisible)`. This covers the button, the sidebar close button, the menu shortcut, and the test harness, because the menu and harness currently flip the same state directly (`mkdn/App/MkdnCommands.swift:159-165`, `mkdn/Core/TestHarness/TestHarnessHandler.swift:131-136`).

**3. Scroll-Anchor Preservation**

Add a `ViewportAnchor` managed by `SelectableTextView.Coordinator` or `LiveResizeScrollView`.

Capture before the first progress tick:

- Force current viewport layout with `textLayoutManager.textViewportLayoutController.layoutViewport()`, matching the existing live-resize backstop (`mkdn/Features/Viewer/Views/SelectableTextView.swift:397-412`).
- Use `NSTextLayoutManager`, `textViewportLayoutController.viewportRange`, and `NSTextContentManager.location(_:offsetBy:)`; the code already uses these to compute visible ranges and locations (`mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+CommentHighlights.swift:21-30`, `mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift:340-356`).
- Enumerate layout fragments from the viewport location with `.ensuresLayout`, as existing geometry code does for code blocks and overlays (`mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+CodeBlocks.swift:95-103`, `mkdn/Features/Viewer/Views/OverlayCoordinator+Positioning.swift:55-61`).
- Store the first visible text line’s `NSTextLocation` plus its pixel offset from the viewport top.

Restore on every progress tick:

- Re-enumerate from the stored `NSTextLocation` with `.ensuresLayout`.
- Compute the new y-position for that line after rewrap.
- Set the clip view origin so the same text line remains at the same viewport y, then call `reflectScrolledClipView`, following the existing scroll paths (`mkdn/Core/TestHarness/TestHarnessHandler+Scroll.swift:38-40`, `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+Comments.swift:372-378`).
- Do a final restore after the animation completes.

Do not reuse the current live-resize origin restore as the full solution. It only saves/restores `bounds.origin` (`mkdn/Features/Viewer/Views/SelectableTextView.swift:422-424`), which cannot preserve semantic position when rewrapping changes heights above the viewport.

**4. 60fps Mechanism**

Use a timer-driven progress ramp, not only SwiftUI implicit animation.

The app already uses 60Hz `DispatchSourceTimer` ramps for comment emphasis and smooth scroll (`mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+Comments.swift:281-296`, `:394-416`), and the test harness uses the same 16ms cadence for simulated scroll (`mkdn/Core/TestHarness/TestHarnessHandler+Scroll.swift:57-68`). Reuse that pattern:

- Add `AnimationConstants.sidebarSlideDuration = 0.35` and define `sidebarSlide` from it; today the duration is embedded in the SwiftUI animation (`mkdn/UI/Theme/AnimationConstants.swift:84-92`).
- `MarkdownPreviewView` owns `@State sidebarProgress`.
- On toggle, start a 60Hz timer from current progress to target progress.
- Each tick updates `sidebarProgress` without implicit SwiftUI animation and passes the new progress into `SelectableTextView`.
- `SelectableTextView.updateNSView` sees progress changes and calls the managed TextKit resize frame.

Per frame, the managed resize frame should:

- Call `layoutViewport()`.
- Restore the captured text anchor.
- Invalidate code-block geometry, since `CodeBlockBackgroundTextView.setFrameSize` already treats width changes as cache invalidation (`mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift:145-149`).
- Reposition attachment overlays immediately.
- Mark the visible rect for redraw.

Also call `OverlayCoordinator.enterLiveResize()` at the start and `exitLiveResize()` at the end so attachment-height churn is deferred and drained through the existing path (`mkdn/Features/Viewer/Views/OverlayCoordinator.swift:228-239`, `:257-305`).

**5. Overlay Interaction**

Attachment overlays must be repositioned synchronously during the sidebar resize. `OverlayCoordinator.repositionOverlays()` already recomputes frames from current TextKit geometry and disables implicit Core Animation actions (`mkdn/Features/Viewer/Views/OverlayCoordinator.swift:113-127`). It also updates `containerState.containerWidth` when width changes (`mkdn/Features/Viewer/Views/OverlayCoordinator.swift:118-120`), and attachment views are created through that coordinator (`mkdn/Features/Viewer/Views/OverlayCoordinator.swift:72-101`, `mkdn/Features/Viewer/Views/OverlayCoordinator+Factories.swift:15-54`).

Comment highlights are drawn layout-passively from visible ranges, so they need visible-rect redraws, not storage edits (`mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+CommentHighlights.swift:33-90`). Badge overlays need their frame synced and repainted; that is currently done from `viewWillDraw` via `syncCommentBadgeOverlay()` (`mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift:286-290`, `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+Comments.swift:111-123`).

The comment popover needs a new hook. It is currently positioned once with constraints when presented (`mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+Comments.swift:215-235`), using `overlayOrigin(near:size:)` (`mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+Comments.swift:471-490`). Add a stored `commentOverlayAnchorRange` when showing comments or adding a comment (`CodeBlockBackgroundTextView+Comments.swift:32-61`, `:183-210`), then on each managed resize frame recompute `boundingRect(forCharacterRange:)` and update the leading/top constraints. The bounding-rect helper already ensures TextKit 2 layout for the requested range (`mkdn/Features/Viewer/Views/NSTextView+CommentHitTest.swift:63-85`).

**6. Reduce Motion**

When Reduce Motion is enabled, do not run the 60Hz width tween. `MotionPreference` maps `.sidebarSlide` to `reducedInstant` under Reduce Motion (`mkdn/UI/Theme/MotionPreference.swift:90-99`), and `reducedInstant` is 0.01s (`mkdn/UI/Theme/AnimationConstants.swift:390`).

Behavior:

- Capture the viewport anchor.
- Set `sidebarProgress` directly to `0` or `1`.
- On the next main-runloop turn, force `layoutViewport()`, restore the anchor once, reposition overlays once, and redraw the visible rect.
- Keep the toggle/sidebar accessibility state consistent with the final progress.

**7. Risks And Verification**

Main risks:

- S1 may not hold 16.7ms/frame on large documents because full-width text rewraps every tick.
- Horizontal reflow is inherent unless S2 reading-column behavior is approved.
- Attachments whose heights depend on width may still settle at the end; final anchor restore is required after `exitLiveResize()`.
- The comment popover can become stale unless it is explicitly re-anchored or dismissed.
- Scroll-spy heading caches must be invalidated during width changes; current coordinator already invalidates on overlay frame changes (`mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift:237-250`).

Verification plan:

- Run `swift build` and `swift test`.
- Use the harness to test default 800x600 and wide windows; resize support already exists (`mkdn/Core/TestHarness/HarnessCommand.swift:106-108`).
- Test top, middle, and deep scroll offsets using the harness scroll command (`mkdn/Core/TestHarness/HarnessCommand.swift:76-77`, `mkdn/Core/TestHarness/TestHarnessHandler+Scroll.swift:25-44`).
- Capture the animation at 60fps using the existing frame capture commands (`mkdn/Core/TestHarness/HarnessCommand.swift:54-65`, `mkdn/Core/TestHarness/FrameCaptureSession.swift:7-12`, `:79-85`).
- Run the capture in both Solarized themes; theme commands already exist (`docs/visual-testing-with-mkdn-ctl.md:23-25`).
- Add a harness diagnostic that reports the top visible anchor before, during, and after toggle. Acceptance: same anchor character/line remains within 1pt vertically after open and close.
- Add visual stress fixtures with long paragraphs, code blocks, comments, images, Mermaid, math, and tables. Acceptance: no blank text regions, no overlay lag, no end snap, and frame count/duration close to requested 60fps (`mkdn/Core/TestHarness/FrameCaptureSession.swift:261-266`).

Bottom line: implement S1 with managed TextKit layout and semantic scroll anchoring. For a literal “no reflow, no jump, always 60fps” guarantee, the product decision must go back to the user: add an S2 reading column, and accept that at the default 800pt window even a normal 700pt column still has to shrink when the 300pt sidebar opens.
