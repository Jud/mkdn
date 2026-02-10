# Root Cause Investigation Report - mermaid-size-001

## Executive Summary
- **Problem**: Mermaid diagrams render at thumbnail size (~60x40px visual appearance) instead of filling the available content width.
- **Root Cause**: Three interacting defects in the attachment-overlay sizing pipeline: (1) NSTextAttachment bounds set to a fixed 1pt width and 200pt height that never update after WKWebView renders, (2) the `OverlayCoordinator.updateAttachmentHeight()` method exists but is never called anywhere, and (3) the `sizeReport` from the WKWebView's JavaScript does not propagate back to the text layout system or trigger attachment bounds updates, creating a permanent mismatch between the WKWebView's rendered diagram and the NSTextView layout fragment that contains it.
- **Solution**: Wire the sizeReport callback from MermaidBlockView through to OverlayCoordinator.updateAttachmentHeight() so the text attachment bounds update after the diagram renders, and TextKit 2 re-lays out the fragment at the correct height.
- **Urgency**: High -- diagrams are functionally unreadable in the current state.

## Investigation Process
- **Duration**: Full systematic investigation
- **Hypotheses Tested**:
  1. **NSTextAttachment bounds are fixed and never update** -- CONFIRMED as primary root cause
  2. **WKWebView renders at zero/tiny initial size due to creation timing** -- CONFIRMED as contributing factor
  3. **aspectRatio modifier with .fit contentMode constrains diagram within too-small bounds** -- CONFIRMED as symptom chain
  4. **sizeReport callback does not propagate to text layout system** -- CONFIRMED as missing linkage
  5. **HTML/CSS template incorrectly sizes SVG** -- RULED OUT (template is correct)
- **Key Evidence**:
  1. `attachment.bounds = CGRect(x: 0, y: 0, width: 1, height: height)` at MarkdownTextStorageBuilder+Blocks.swift:129 with `height` = 200 (the `attachmentPlaceholderHeight` constant) -- never updated after initial creation
  2. `OverlayCoordinator.updateAttachmentHeight()` exists at OverlayCoordinator.swift:86 but has zero call sites in the entire codebase
  3. `MermaidBlockView` receives `renderedHeight` and `renderedAspectRatio` via @State but has no mechanism to communicate these back to the OverlayCoordinator

## Root Cause Analysis

### Technical Details

The mermaid diagram sizing pipeline has a broken feedback loop between three components. The full causation chain is documented below.

#### Component 1: NSTextAttachment Bounds (MarkdownTextStorageBuilder+Blocks.swift:121-144)

```swift
// File: /Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift
// Lines 128-129
static func appendAttachmentBlock(...) {
    let attachment = NSTextAttachment()
    attachment.bounds = CGRect(x: 0, y: 0, width: 1, height: height)
    // height = attachmentPlaceholderHeight = 200
    // width = 1 (this is a "width doesn't matter" placeholder)
```

The attachment is created with a **fixed** 1pt width and 200pt height. These bounds determine how TextKit 2 lays out the attachment character in the text storage. The `layoutFragmentFrame` for this attachment will have a height of approximately 200pt. This is intended as an initial placeholder that should be updated once the diagram renders. However, **no code ever updates these bounds**.

#### Component 2: Overlay Positioning (OverlayCoordinator.swift:240-277)

```swift
// File: /Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift
// Lines 269-275
let fragmentFrame = fragment.layoutFragmentFrame
entry.view.frame = CGRect(
    x: fragmentFrame.origin.x + context.origin.x,
    y: fragmentFrame.origin.y + context.origin.y,
    width: context.containerWidth,
    height: fragmentFrame.height  // Always ~200pt from the fixed attachment bounds
)
```

The overlay (an NSHostingView wrapping MermaidBlockView) is sized to `containerWidth x fragmentFrame.height`. The width correctly uses the full text container width. The height comes from the `layoutFragmentFrame`, which is determined by the NSTextAttachment bounds (fixed at 200pt). This height **never changes** because the attachment bounds never change.

#### Component 3: Orphaned Update Method (OverlayCoordinator.swift:86-109)

```swift
// File: /Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift
// Lines 86-109
func updateAttachmentHeight(blockIndex: Int, newHeight: CGFloat) {
    guard let entry = entries[blockIndex],
          let textView,
          let textStorage = textView.textStorage
    else { return }

    let attachment = entry.attachment
    guard abs(attachment.bounds.height - newHeight) > 1 else { return }

    attachment.bounds = CGRect(
        x: 0, y: 0,
        width: attachment.bounds.width,
        height: newHeight
    )
    // ... invalidates text storage and repositions overlays
}
```

This method correctly updates the attachment bounds, invalidates the text storage layout, and repositions overlays. **It has zero call sites.** It was clearly written to be called when the diagram finishes rendering, but the wiring was never completed.

#### Component 4: WKWebView Size Reporting (MermaidWebView.swift + MermaidBlockView.swift)

The WKWebView renders the mermaid diagram, and the JavaScript `sizeReport` message handler posts the SVG's bounding rect dimensions:

```javascript
// File: /Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html
// Lines 46-49
var bbox = svg.getBoundingClientRect();
window.webkit.messageHandlers.sizeReport.postMessage({
    width: bbox.width, height: bbox.height
});
```

The Swift coordinator receives this and updates the bindings:

```swift
// File: /Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift
// Lines 204-205
parent.renderedHeight = max(height, 1)
parent.renderedAspectRatio = height / width
```

These flow to `MermaidBlockView`'s `@State` properties. However, MermaidBlockView has **no reference** to the OverlayCoordinator and **no callback** to communicate the rendered dimensions back to the overlay/attachment system.

#### Component 5: Aspect Ratio Constraint (MermaidBlockView.swift:72-81)

```swift
// File: /Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift
// Lines 72-81
if renderState == .rendered {
    content
        .aspectRatio(
            1 / renderedAspectRatio,  // width/height ratio
            contentMode: .fit
        )
} else {
    content
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
}
```

When the render completes, the view switches to an aspect-ratio-constrained layout with `.fit` contentMode. Within the overlay's fixed 200pt height container, the `.fit` mode ensures the diagram maintains its aspect ratio while fitting within the available space. For many diagram shapes, this significantly reduces the visible diagram size.

#### Component 6: WKWebView Initial Size Race (MermaidWebView.swift + OverlayCoordinator.swift)

There is a timing issue in the overlay creation sequence:

1. `createOverlay()` at OverlayCoordinator.swift:166-197 creates the NSHostingView and adds it as a subview of the textView with a **zero frame** (before `repositionOverlays()` runs)
2. Adding the NSHostingView triggers SwiftUI view creation, including `MermaidWebView.makeNSView()`, which creates the WKWebView with `frame: container.bounds` -- zero bounds at this point
3. `loadTemplate()` starts loading the HTML with Mermaid.js
4. Then `repositionOverlays()` sets the overlay frame to proper dimensions
5. Auto layout constraints resize the WKWebView to match
6. The HTML/JS may have already executed `render()` by this point, or may execute it after the resize

If the `render()` function executes while the WKWebView still has zero/tiny dimensions, the SVG renders at that width. The CSS `#diagram svg { width: 100%; }` would make the SVG width equal the viewport width (zero or near-zero). The `getBoundingClientRect()` would then report very small dimensions. The sizeReport guard (`width > 0`) would filter out zero-width, but a width of e.g. 1px would pass through, resulting in a tiny `renderedAspectRatio`.

Even if the WKWebView subsequently resizes and the SVG re-flows via CSS, the `sizeReport` is sent only once (in the `render()` function callback) and is never re-sent on resize.

### Causation Chain

```
Root Cause: Missing feedback loop from WKWebView render -> attachment bounds update
  |
  +-> NSTextAttachment.bounds stays at (0, 0, 1, 200) forever
  |     |
  |     +-> TextKit 2 layoutFragmentFrame height stays at ~200pt
  |           |
  |           +-> Overlay frame height stays at ~200pt
  |                 |
  |                 +-> NSHostingView proposes (containerWidth x 200) to MermaidBlockView
  |                       |
  |                       +-> .aspectRatio(.fit) constrains diagram within 200pt height
  |                             |
  |                             +-> Diagram appears smaller than intended
  |
  +-> WKWebView created at zero size (timing issue)
        |
        +-> Mermaid.js may render SVG at zero/tiny viewport width
        |     |
        |     +-> sizeReport sends wrong dimensions (or is filtered by width > 0 guard)
        |
        +-> sizeReport sent only once, not re-sent on WKWebView resize
              |
              +-> renderedAspectRatio may be wrong or remain at default (0.5)
                    |
                    +-> .aspectRatio produces wrong proportions
```

### Why It Occurred

The mermaid rendering architecture was recently migrated from a synchronous pipeline (JSC + beautiful-mermaid -> SVG -> SwiftDraw -> NSImage) to an asynchronous WKWebView-based pipeline. The text attachment overlay system was designed with the `updateAttachmentHeight()` method to handle post-render size updates, but the wiring between the MermaidBlockView's size callback and the OverlayCoordinator was never completed during the migration. The `MermaidBlockView` was originally a standalone SwiftUI view (rendered directly via `MarkdownBlockView`), and when it was moved into the NSTextView overlay system, the size feedback mechanism was not connected.

## Proposed Solutions

### 1. Recommended: Wire sizeReport to attachment height update (Primary Fix)

**Approach**: Add a callback from MermaidBlockView to OverlayCoordinator that updates the text attachment bounds when the diagram finishes rendering.

**Specific changes**:
1. Add an `onSizeChange` callback closure to `MermaidBlockView` that fires when `renderedHeight` or `renderedAspectRatio` changes
2. In `OverlayCoordinator.makeMermaidOverlay()`, pass a closure that calls `updateAttachmentHeight(blockIndex:newHeight:)` with the computed height based on container width and aspect ratio
3. Fix `updateAttachmentHeight` to also update the width (currently preserves the 1pt width)
4. Add a `ResizeObserver` or `MutationObserver` in the JavaScript template to re-send `sizeReport` when the WKWebView viewport changes, ensuring the aspect ratio is always correct

**Effort**: 2-3 hours
**Risk**: Low -- the core mechanism (`updateAttachmentHeight`) already exists and is tested in its internal logic
**Pros**: Clean architectural fix using the existing update method; correctly integrates the asynchronous rendering lifecycle
**Cons**: None significant

### 2. Alternative A: Set larger initial attachment height and use resize observer

**Approach**: Set the initial attachment height to a reasonable default (e.g., 400pt) and add a JavaScript resize observer that re-sends `sizeReport` whenever the WKWebView viewport changes. This ensures the diagram eventually gets correct dimensions even without the Swift-side feedback loop.

**Effort**: 1-2 hours
**Risk**: Medium -- does not fix the fundamental feedback loop; the diagram height will be wrong until the resize observer fires; may cause visible "jump" when the attachment resizes

### 3. Alternative B: Replace overlay approach with NSTextAttachmentViewProvider (TextKit 2 native)

**Approach**: Instead of manually positioning overlays, use TextKit 2's `NSTextAttachmentViewProvider` to provide views for text attachments. This is the recommended TextKit 2 approach for embedding arbitrary views in text content. The view provider would return the MermaidBlockView's NSHostingView, and TextKit 2 would handle sizing and positioning natively.

**Effort**: 4-6 hours
**Risk**: Medium-high -- requires significant refactoring of the overlay system; TextKit 2's NSTextAttachmentViewProvider has specific requirements for sizing that would need careful implementation
**Pros**: Uses Apple's recommended approach; eliminates manual overlay positioning entirely
**Cons**: Larger change scope; may introduce new layout issues

## Prevention Measures

1. **Integration testing for overlay-based views**: Add a test that verifies mermaid diagram overlays are rendered at a reasonable size (width close to container width, height proportional to diagram content)
2. **Dead code detection**: The `updateAttachmentHeight` method having zero call sites should have been flagged during code review. Consider adding a lint rule or CI check for public/internal methods with no call sites
3. **End-to-end size verification**: The visual verification workflow should include a specific check for mermaid diagram dimensions, comparing rendered size against expected proportions

## Evidence Appendix

### Evidence 1: Fixed attachment bounds
File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`
Lines 128-129:
```swift
let attachment = NSTextAttachment()
attachment.bounds = CGRect(x: 0, y: 0, width: 1, height: height)
```
Where `height` = `attachmentPlaceholderHeight` = 200 (line 32 of MarkdownTextStorageBuilder.swift).

### Evidence 2: Orphaned updateAttachmentHeight method
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`
Lines 86-109: Method defined but grep confirms zero call sites across entire codebase:
```
$ grep -r "updateAttachmentHeight" mkdn/
mkdn/Features/Viewer/Views/OverlayCoordinator.swift:    func updateAttachmentHeight(blockIndex: Int, newHeight: CGFloat) {
```

### Evidence 3: Size callback dead-ends in MermaidBlockView
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`
Lines 17-18: `@State private var renderedHeight` and `@State private var renderedAspectRatio` are updated by the WKWebView sizeReport handler but are only consumed locally by the `.aspectRatio` modifier. No mechanism exists to propagate these values to the OverlayCoordinator.

### Evidence 4: sizeReport sent only once
File: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html`
Lines 41-56: The `render()` function sends `sizeReport` exactly once after `mermaid.run()` completes. There is no resize observer or subsequent reporting.

### Evidence 5: WKWebView created at zero size
File: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`
Line 61: `let webView = WKWebView(frame: container.bounds, configuration: configuration)` -- `container.bounds` is zero at creation time because the NSHostingView frame hasn't been set yet (repositionOverlays runs after createOverlay).

### Evidence 6: Visual confirmation from screenshots
Files:
- `/Users/jud/Projects/mkdn/.rp1/work/verification/captures/mermaid-focus-solarizedDark-previewOnly.png`
- `/Users/jud/Projects/mkdn/.rp1/work/verification/captures/mermaid-focus-solarizedLight-previewOnly.png`

Both screenshots show section headings ("Flowchart", "Sequence Diagram", "Class Diagram") with description text, but the mermaid diagrams between them appear as tiny, barely visible elements rather than full-width diagrams.

### Evidence 7: No updateNSView re-render on resize
File: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`
Lines 85-101: `updateNSView` only handles focus changes and theme changes. It does not reload the template or trigger a re-render when the container size changes, so even after the overlay is properly positioned, the WKWebView content is not re-rendered at the new size.
