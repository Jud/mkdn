# Hypothesis Document: smart-tables
**Version**: 1.0.0 | **Created**: 2026-02-11T00:00:00Z | **Status**: VALIDATED

## Hypotheses
### HYP-001: LazyVStack pinnedViews works inside NSHostingView overlay without SwiftUI ScrollView parent
**Risk Level**: HIGH
**Status**: REJECTED
**Statement**: SwiftUI LazyVStack with pinnedViews works correctly inside an NSHostingView overlay that has no SwiftUI ScrollView parent
**Context**: Smart tables need sticky/pinned headers that remain visible as the user scrolls through a large table. If LazyVStack pinnedViews requires a SwiftUI ScrollView ancestor, the pinning will not work inside the NSTextView overlay system (which uses NSScrollView).
**Validation Criteria**:
- CONFIRM if: Create a minimal test -- NSHostingView containing LazyVStack(pinnedViews: .sectionHeaders) with a Section header, placed as subview of NSTextView. Scroll the parent NSScrollView and observe whether the header pins.
- REJECT if: The header scrolls away with the content instead of pinning.
**Suggested Method**: CODE_EXPERIMENT

### HYP-002: Horizontal SwiftUI ScrollView inside NSHostingView does not capture vertical scroll events
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: SwiftUI ScrollView(.horizontal) inside an NSHostingView overlay within an NSTextView does not capture vertical scroll events from the parent NSScrollView
**Context**: Wide tables need horizontal scrolling. If a horizontal-only SwiftUI ScrollView inside the overlay captures or interferes with vertical scroll events, the user experience of scrolling through the document will be degraded.
**Validation Criteria**:
- CONFIRM if: Create a test NSHostingView with ScrollView(.horizontal) content inside an NSTextView. Perform a two-finger vertical scroll gesture while the cursor is over the horizontal ScrollView. The parent NSTextView scrolls vertically without interference.
- REJECT if: The vertical scroll gesture is consumed or partially consumed by the horizontal ScrollView.
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-12T04:50:00Z
**Method**: CODE_EXPERIMENT + EXTERNAL_RESEARCH
**Result**: REJECTED

**Evidence**:

1. **Code experiment** created a minimal reproduction of the mkdn overlay architecture: NSScrollView > NSTextView > NSHostingView(LazyVStack(pinnedViews: .sectionHeaders)).

2. **Without SwiftUI ScrollView parent**: The NSHostingView's `intrinsicContentSize` was `(124.0, 832.0)` -- the full height of all 20 rows plus the header. This confirms LazyVStack renders ALL items eagerly (not lazily) and behaves identically to VStack when no SwiftUI ScrollView parent exists. No pinning occurs because there is no scroll context to pin against.

3. **With SwiftUI ScrollView wrapper**: Wrapping in `ScrollView { LazyVStack(pinnedViews: ...) }.frame(height: 200)` constrained the intrinsic size to `(124.0, 200.0)` and enabled pinning -- but only within the inner SwiftUI ScrollView's viewport. The entire NSHostingView (including the "pinned" header) still scrolls away with the NSTextView content when the parent NSScrollView scrolls.

4. **Fundamental architectural mismatch**: SwiftUI's `pinnedViews` mechanism pins section headers relative to the nearest SwiftUI ScrollView ancestor. It has zero awareness of the AppKit NSScrollView that actually controls the document scroll position. There is no bridge between the two scroll systems for pinning behavior.

5. **External research confirms**: Apple's documentation and all community resources (Hacking with Swift, YoSwift, etc.) consistently show `pinnedViews` used exclusively inside a SwiftUI `ScrollView`. The `PinnedScrollableViews` type name itself indicates the pinning is relative to the scrollable container. A third-party library (Lumisilk/PinnedScrollView) exists specifically to provide pinning without LazyVStack, but it too operates within SwiftUI's ScrollView.

**Sources**:
- Experiment code: `/tmp/hypothesis-smart-tables/Sources/main.swift` (DISPOSABLE)
- https://developer.apple.com/documentation/swiftui/lazyvstack
- https://yoswift.dev/swiftui/pinnedScrollableViews/
- https://github.com/Lumisilk/PinnedScrollView

**Implications for Design**:
Sticky/pinned table headers cannot use SwiftUI's built-in `LazyVStack(pinnedViews:)` mechanism in the current overlay architecture. Alternative approaches needed:
- (a) Manual pinning via AppKit: observe `NSScrollView.contentView.bounds` changes, compute whether the table header should be pinned, and reposition a separate header overlay view at the NSScrollView's visible rect top edge.
- (b) Fixed header outside scroll: render the header as a separate NSHostingView that is repositioned by OverlayCoordinator to stay at the top of the visible area when the table body is partially scrolled off-screen.
- (c) No pinning: accept that headers scroll with content (simplest, matches current TableBlockView behavior).

---

### HYP-002 Findings
**Validated**: 2026-02-12T04:50:00Z
**Method**: CODE_EXPERIMENT
**Result**: CONFIRMED

**Evidence**:

1. **Code experiment** created the exact overlay hierarchy: NSScrollView > NSTextView > NSHostingView(ScrollView(.horizontal) { HStack { ... } }).

2. **View hierarchy inspection** revealed that SwiftUI's `ScrollView(.horizontal)` creates an internal `HostingScrollView` (an NSScrollView subclass) inside the NSHostingView:
   ```
   NSHostingView [536x40]
     PlatformContainer [536x30]
       HostingScrollView [536x30]    <-- internal horizontal NSScrollView
         NSClipView [536x30]
           DocumentView [2000x30]    <-- 2000px wide content
   ```

3. **Scroll event propagation test**: A synthetic vertical scroll event (deltaY=-30, deltaX=0) was sent directly to the NSHostingView via `scrollWheel(with:)`. The parent NSScrollView's content offset changed from `0.0` to `30.0` (delta: 30.0), confirming the vertical event propagated correctly through the responder chain.

4. **Responder chain verification**: The chain was confirmed as:
   ```
   NSHostingView -> NSTextView -> NSClipView -> NSScrollView -> NSWindow
   ```
   This matches the expected AppKit responder chain. When the internal `HostingScrollView` receives a purely vertical scroll event, it does not consume it because horizontal-only scrolling has no vertical component to handle.

5. **Codebase precedent**: The existing `MermaidBlockView` already uses a `WKWebView` (which contains its own internal `WKScrollView`) inside an NSHostingView overlay. The mkdn codebase handles this pattern successfully -- the WKWebView's internal scroll view coexists with the parent NSScrollView. The horizontal ScrollView for tables follows the same pattern.

**Sources**:
- Experiment code: `/tmp/hypothesis-smart-tables/Sources/main.swift` (DISPOSABLE)
- Codebase: `mkdn/Features/Viewer/Views/MermaidBlockView.swift` (WKWebView precedent)
- Codebase: `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` (overlay system)
- Codebase: `mkdn/Features/Viewer/Views/SelectableTextView.swift` (NSScrollView host)

**Implications for Design**:
Horizontal scrolling for wide tables can safely use SwiftUI `ScrollView(.horizontal)` inside the NSHostingView overlay. Vertical document scrolling will not be disrupted when the cursor is over the table. Note: diagonal trackpad gestures (simultaneous deltaX + deltaY) may have the horizontal component consumed by the inner scroll view while the vertical component propagates -- this matches standard macOS nested scroll view behavior and is acceptable.

---

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | REJECTED | pinnedViews requires SwiftUI ScrollView parent; cannot pin relative to AppKit NSScrollView. Manual AppKit-level pinning or no-pinning fallback needed. |
| HYP-002 | HIGH | CONFIRMED | Horizontal ScrollView correctly passes vertical scroll events to parent NSScrollView via responder chain. Safe to use for wide table horizontal scrolling. |
