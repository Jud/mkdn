# Root Cause Investigation Report - table-scroll-capture

## Executive Summary
- **Problem**: Tables rendered as overlay views capture scroll events, preventing normal document scrolling when the cursor is over a table.
- **Root Cause**: `TableBlockView` wraps its content in `ScrollView(.horizontal)`, which creates an `NSScrollView` inside the `NSHostingView` overlay. This nested scroll view intercepts both horizontal and vertical scroll events before they can reach the parent document `NSScrollView`.
- **Solution**: Remove the `ScrollView(.horizontal)` wrapper from `TableBlockView`, replacing it with a non-scrollable container layout.
- **Urgency**: Medium -- affects usability for any document containing tables.

## Investigation Process
- **Hypotheses Tested**: 3 (see below)
- **Key Evidence**: Source code analysis of `TableBlockView.swift`, `OverlayCoordinator.swift`, `MermaidWebView.swift`, and `SelectableTextView.swift`

### Hypothesis 1: `ScrollView(.horizontal)` in TableBlockView is the culprit -- CONFIRMED

**Evidence for:**
- `TableBlockView.swift` line 15: `ScrollView(.horizontal, showsIndicators: true)` wraps the entire table body.
- When SwiftUI's `ScrollView` is hosted inside an `NSHostingView`, SwiftUI creates an internal `NSScrollView` (or equivalent scroll infrastructure). This nested scroll view becomes part of the AppKit responder chain.
- On macOS, `NSScrollView` handles `scrollWheel:` events. When the user scrolls over a table overlay, the AppKit hit-test resolves to the `NSHostingView`'s internal scroll infrastructure, which consumes the scroll event rather than letting it propagate to the parent document `NSScrollView` managed by `SelectableTextView`.
- Vertical scroll events are also captured because `NSScrollView` intercepts `scrollWheel:` even for axes it cannot scroll on -- it only forwards the event to its parent if it explicitly decides it cannot handle it, and SwiftUI's internal scroll view may not implement that forwarding correctly.

**Evidence against alternative explanations:**
- The `NSHostingView` itself does not override `hitTest` or `scrollWheel:` -- it is a plain `NSHostingView(rootView:)` created at `OverlayCoordinator.swift` line 268. The scroll capture comes from the SwiftUI `ScrollView` inside it, not from the hosting view.

### Hypothesis 2: Missing hitTest gating (like MermaidContainerView) -- CONTRIBUTING FACTOR but not root cause

**Evidence:**
- `MermaidWebView.swift` lines 14-21 define `MermaidContainerView`, a custom `NSView` that overrides `hitTest(_:)` to return `nil` when unfocused. This explicitly prevents scroll/click events from reaching the `WKWebView`.
- The table overlay path (`OverlayCoordinator.makeTableOverlay()` at line 261-268) creates a bare `NSHostingView` with no hitTest gating. There is no focus-based interaction model for tables.
- However, even without a focus gate, the scroll capture would not occur if `TableBlockView` did not contain a `ScrollView`. The hitTest issue is secondary -- the primary cause is the scrollable container itself.

### Hypothesis 3: NSHostingView itself consumes scroll events generically -- REJECTED

**Evidence against:**
- The thematic break overlay (line 251-258) also uses a bare `NSHostingView` wrapping a simple `Color.frame(height:1)` view. Thematic breaks do NOT capture scroll events. This proves that `NSHostingView` alone does not cause scroll capture.
- The difference is that `TableBlockView` contains a `ScrollView` while the thematic break view does not.

## Root Cause Analysis

### Technical Details

**File**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/TableBlockView.swift`, line 15
**Issue**: `ScrollView(.horizontal, showsIndicators: true)` wrapping the table content

**Secondary contributor**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`, lines 261-268
**Issue**: `makeTableOverlay()` creates a plain `NSHostingView` with no event passthrough mechanism

### Causation Chain

```
Root Cause: TableBlockView contains ScrollView(.horizontal)
    |
    v
SwiftUI's ScrollView creates internal NSScrollView-like scroll infrastructure
inside the NSHostingView
    |
    v
NSHostingView is added as a subview of the NSTextView (document view)
via OverlayCoordinator.createOverlay() -> textView.addSubview(overlayView)
    |
    v
AppKit hit-testing resolves scroll events over table regions to the
NSHostingView's internal scroll infrastructure
    |
    v
The internal scroll view consumes scrollWheel: events
(both horizontal AND vertical axes)
    |
    v
SYMPTOM: Scroll events do not propagate to the parent NSScrollView
(the document scroll view from SelectableTextView.makeNSView)
```

### Why It Occurred

1. `TableBlockView` was likely given `ScrollView(.horizontal)` to handle wide tables that overflow the container width -- a reasonable UX pattern in isolation.
2. However, tables are rendered as overlay `NSHostingView` subviews positioned over `NSTextAttachment` placeholders in the `NSTextView`. In this AppKit-hosted-SwiftUI context, a nested `ScrollView` creates a scroll event sink that competes with the parent document scrolling.
3. The `CodeBlockView` also uses `ScrollView(.horizontal)` (line 26), but code blocks are rendered inline in the `NSAttributedString` via `appendCodeBlock()` -- they are NOT overlay views. They are drawn as styled text with `CodeBlockBackgroundTextView` handling the background rendering. So the same pattern does not cause problems for code blocks. (Note: if code blocks were ever moved to the overlay system, they would exhibit the same scroll capture bug.)
4. The Mermaid overlay solved this with an explicit `MermaidContainerView` that gates `hitTest`, but no equivalent was created for tables. Tables lack the focus-based interaction model that Mermaid diagrams have (click-to-focus / Escape-to-unfocus).

### Architectural Note

The `MarkdownBlockView.swift` (pure SwiftUI path) also renders tables via `TableBlockView` (line 54), but this path is only used in SwiftUI-native contexts. The preview pane uses the TextKit 2 / `NSTextView` path where tables are overlay-hosted. The scroll capture bug manifests specifically in the overlay hosting path.

## Proposed Solutions

### 1. Recommended: Remove ScrollView from TableBlockView

**Approach**: Replace `ScrollView(.horizontal, showsIndicators: true)` with a simple container (e.g., just the `VStack` directly, or a `Group`). Wide tables would be clipped or wrapped rather than horizontally scrollable.

**Effort**: Small (~15 minutes). One-line structural change in `TableBlockView.swift`.

**Risk**: Low. Tables wider than the container will be clipped. This matches the expected behavior stated in the bug report ("Table content should be visually styled but not independently scrollable").

**Pros**:
- Directly eliminates the root cause
- No new AppKit plumbing needed
- Both the SwiftUI path and the overlay path benefit

**Cons**:
- Very wide tables may have content clipped. Could be mitigated with `fixedSize()` or flexible column widths.

### 2. Alternative A: Add hitTest gating to table overlay NSHostingView

**Approach**: Create a `TableContainerView: NSView` (similar to `MermaidContainerView`) that always returns `nil` from `hitTest(_:)`, and wrap the `NSHostingView` inside it. This would let all events pass through to the document.

**Effort**: Medium (~30 minutes). New NSView subclass, update `makeTableOverlay()`.

**Risk**: Low-medium. Would also block text selection within tables (`.textSelection(.enabled)` on line 52 would stop working). May need a focus model similar to Mermaid if text selection in tables is desired.

**Pros**:
- Follows the established pattern from MermaidWebView
- Keeps the horizontal scroll capability for wide tables (though it would only be accessible when focused)

**Cons**:
- More code
- Requires a focus/unfocus interaction model if text selection is desired
- Over-engineers the solution if horizontal scrolling is not actually needed

### 3. Alternative B: Override scrollWheel on NSHostingView

**Approach**: Subclass `NSHostingView` and override `scrollWheel(_:)` to forward the event to `nextResponder` (the parent `NSTextView`).

**Effort**: Medium (~30 minutes). New NSHostingView subclass, update overlay factory.

**Risk**: Medium. Forwarding scroll events manually can introduce jankiness, and may interact poorly with SwiftUI's internal scroll handling. Also, this still leaves the horizontal ScrollView functional but unfocused, which could cause confusing partial-scroll behavior.

**Pros**:
- Preserves horizontal scrollability for wide tables
- No focus model needed

**Cons**:
- Fragile -- relies on AppKit event forwarding details
- May need separate handling for horizontal vs vertical events
- SwiftUI's ScrollView may still consume the momentum phase of scroll events

## Prevention Measures

1. **Overlay view audit**: Any SwiftUI view used as an overlay in `OverlayCoordinator` should be reviewed for scroll containers. Views destined for overlay hosting should avoid `ScrollView` unless accompanied by explicit event gating.
2. **Pattern documentation**: Document the constraint that overlay-hosted SwiftUI views must not contain `ScrollView` (or must gate it behind a focus model) in the codebase patterns or architecture docs.
3. **Test coverage**: Add a manual or automated scroll-passthrough test for overlay elements -- verify that scrolling over each overlay type (mermaid, image, thematic break, table) properly scrolls the document.

## Evidence Appendix

### E1: TableBlockView ScrollView wrapper
```swift
// TableBlockView.swift:14-68
var body: some View {
    ScrollView(.horizontal, showsIndicators: true) {  // <-- ROOT CAUSE
        VStack(alignment: .leading, spacing: 0) {
            // ... table header and rows ...
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(...)
    }
}
```

### E2: OverlayCoordinator table factory (no event gating)
```swift
// OverlayCoordinator.swift:261-268
private func makeTableOverlay(
    columns: [TableColumn],
    rows: [[AttributedString]],
    appSettings: AppSettings
) -> NSView {
    let rootView = TableBlockView(columns: columns, rows: rows)
        .environment(appSettings)
    return NSHostingView(rootView: rootView)  // <-- bare NSHostingView, no hitTest override
}
```

### E3: MermaidContainerView hitTest gating (reference pattern)
```swift
// MermaidWebView.swift:14-21
final class MermaidContainerView: NSView {
    var allowsInteraction = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard allowsInteraction else { return nil }  // <-- blocks events when unfocused
        return super.hitTest(point)
    }
}
```

### E4: CodeBlockView uses same ScrollView but is NOT overlay-hosted
```swift
// CodeBlockView.swift:26 -- also has ScrollView(.horizontal)
// But code blocks are rendered inline via appendCodeBlock() in MarkdownTextStorageBuilder
// They are NOT overlay views, so no scroll capture issue
```

### E5: ThematicBreak overlay proves NSHostingView alone is harmless
```swift
// OverlayCoordinator.swift:251-258
private func makeThematicBreakOverlay(appSettings: AppSettings) -> NSView {
    let borderColor = appSettings.theme.colors.border
    let rootView = borderColor.frame(height: 1).padding(.vertical, 8)
    return NSHostingView(rootView: rootView)  // <-- no ScrollView, no scroll capture
}
```
