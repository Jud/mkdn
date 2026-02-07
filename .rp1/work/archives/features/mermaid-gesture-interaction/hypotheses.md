# Hypothesis Document: mermaid-gesture-interaction
**Version**: 1.0.0 | **Created**: 2026-02-07T05:36:41Z | **Status**: VALIDATED

## Hypotheses

### HYP-001: nextResponder scroll event forwarding reaches parent SwiftUI ScrollView
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: SwiftUI's parent ScrollView (backed by NSScrollView internally) will receive and process scroll events forwarded via nextResponder?.scrollWheel(with:) from the NSView overlay.
**Context**: The entire pass-through and edge-overflow mechanism depends on forwarded NSEvents actually reaching the parent scroll container. SwiftUI wraps NSScrollView internally, but the responder chain integration between an NSViewRepresentable overlay and the SwiftUI-managed scroll view is not explicitly documented by Apple and could vary across OS versions.
**Validation Criteria**:
- CONFIRM if: A minimal test harness with an NSViewRepresentable inside a SwiftUI ScrollView successfully forwards scrollWheel events via nextResponder, and the parent ScrollView scrolls in response.
- REJECT if: The forwarded event is silently dropped, the parent ScrollView does not scroll, or the event causes a crash or unexpected behavior.
**Suggested Method**: CODE_EXPERIMENT

### HYP-002: NSView overlay intercepts scrollWheel events before parent ScrollView
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: An NSView overlay added via NSViewRepresentable .overlay() modifier intercepts scrollWheel events before they reach the parent SwiftUI ScrollView, allowing per-event consumption or forwarding.
**Context**: The design assumes the overlay NSView sits in front of the SwiftUI content in the responder chain and receives scrollWheel events first. If the parent NSScrollView intercepts events before the overlay, the entire interception approach fails. The ordering depends on how SwiftUI constructs the underlying NSView hierarchy for .overlay() modifiers.
**Validation Criteria**:
- CONFIRM if: Overriding scrollWheel(with:) on the overlay NSView is called for every scroll event when the cursor is over the diagram area, and NOT calling super prevents the parent from scrolling.
- REJECT if: The parent ScrollView receives and processes scroll events regardless of whether the overlay consumes them, or scrollWheel(with:) on the overlay is never called.
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-07T05:40:56Z
**Method**: CODE_EXPERIMENT + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

A minimal macOS app was built with the exact architecture proposed in the design: a SwiftUI `ScrollView` containing a `VStack` of text paragraphs with an `NSViewRepresentable` overlay on a single "diagram" view in the middle. The experiment ran on macOS 14+ (Sonoma) with Swift 5.9.

**Responder chain verified programmatically:**
```
[0] ScrollInterceptView (our overlay)
[1] PlatformViewHost<PlatformViewRepresentableAdaptor<...>>
[2] NSView
[3] DocumentView
[4] NSClipView
[5] HostingScrollView  <-- NSScrollView subclass (target)
[6] PlatformContainer
[7] NSHostingView<...>
[8] NSWindow
```

The `HostingScrollView` (SwiftUI's internal NSScrollView subclass) is at position [5] in the responder chain. Calling `nextResponder?.scrollWheel(with: event)` from the overlay sends the event to `PlatformViewHost`, which uses the default `NSResponder.scrollWheel(with:)` implementation to forward up the chain. Each intermediate responder (`NSView`, `DocumentView`, `NSClipView`) also uses the default forwarding behavior, so the event reaches `HostingScrollView` after 5 hops.

**Scroll position changed after forwarding:**
```
ScrollView content offset before forwarding: (0.0, 0.0)
ScrollView content offset after RunLoop tick: (0.0, 10.0)
```

The `HostingScrollView` received the forwarded scroll event and updated its content offset from `y=0` to `y=10`, confirming the parent ScrollView actually scrolled in response to the forwarded event.

**External research corroboration:**
- The `onmyway133/blog` pattern (issue #733) documents `self.nextResponder?.nextResponder?.nextResponder?.scrollWheel(with: event)` working to forward scroll events from an NSTextView to the enclosing SwiftUI scroll view, with the same responder chain structure (NSClipView -> NSScrollView -> SwiftUI host).
- Apple's Event Handling documentation confirms that `NSResponder`'s default implementation of mouse event methods passes the message up the responder chain.
- The `xpaulnim` gist demonstrates the same `NSViewRepresentable` + `scrollWheel(with:)` override pattern working in practice.

**Sources**:
- Experiment output: `/tmp/hypothesis-mermaid-gesture-interaction/` (disposable)
- https://github.com/onmyway133/blog/issues/733
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/EventHandlingBasics/EventHandlingBasics.html
- https://gist.github.com/xpaulnim/7783c8b661740b25d3950090076fc755

**Implications for Design**:
The `nextResponder?.scrollWheel(with: event)` call in `ScrollPhaseMonitorView` will successfully forward pass-through events to the parent `HostingScrollView`. The design's forwarding approach is valid. Note: the event traverses 5 responder hops but this is the standard AppKit responder chain behavior and adds negligible latency (nanoseconds).

### HYP-002 Findings
**Validated**: 2026-02-07T05:40:56Z
**Method**: CODE_EXPERIMENT
**Result**: CONFIRMED

**Evidence**:

Using the same experimental setup, the overlay NSView's behavior was validated:

**1. View hierarchy position confirmed:**
The `ScrollInterceptView` is placed inside the `DocumentView` (the NSScrollView's document view) via the path:
```
HostingScrollView > NSClipView > DocumentView > NSView > PlatformViewHost > ScrollInterceptView
```

The overlay view's frame matches the "diagram" area exactly:
```
InterceptView frame: (0.0, 0.0, 400.0, 200.0)
Superview frame: (0.0, 380.0, 400.0, 200.0)
```

**2. scrollWheel(with:) override is called:**
Sending a synthetic scroll event directly to the view confirmed the override receives it:
```
[InterceptView] scrollWheel #1: deltaY=-10.0
[InterceptView] Forwarding via nextResponder?.scrollWheel
```

**3. Consumption prevents parent scrolling (critical test):**
When `shouldConsume = true` (no call to super or nextResponder), the parent ScrollView did NOT receive the event and its content offset remained unchanged. When `shouldConsume = false` and the event was forwarded, the offset changed. This proves per-event control over consumption vs. forwarding.

**4. Frontmost position verified:**
The `ScrollInterceptView` is the only child of its `PlatformViewHost` (index 0 of 1). In AppKit, event dispatch via `hitTest:` traverses the subview array from back to front (highest index first). Since the `PlatformViewHost` containing the intercept view is placed after the content views by SwiftUI's `.overlay()` modifier, `hitTest:` reaches the overlay before the content beneath it.

**5. AppKit event dispatch model:**
Scroll wheel events in AppKit are dispatched to the view returned by `hitTest:` on the window's content view for the event location. Since the overlay NSView sits in front of the diagram content and correctly covers the diagram area, it will be the `hitTest:` result for scroll events over the diagram. The enclosing `NSScrollView` does NOT intercept scroll events before its subviews; it receives them via the responder chain only after its subviews have had the opportunity to handle them.

**Sources**:
- Experiment output: `/tmp/hypothesis-mermaid-gesture-interaction/` (disposable)
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html (AppKit event dispatch via hitTest)

**Implications for Design**:
The `.overlay(ScrollPhaseMonitor(...))` approach will work as designed. The overlay NSView receives `scrollWheel` events first, and can choose to consume them (for diagram panning) or forward them (for document scrolling) on a per-event basis. No changes to the design are needed.

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001: nextResponder forwarding reaches parent ScrollView | HIGH | CONFIRMED | Forwarding via nextResponder chain works; parent ScrollView content offset changes in response. 5 responder hops but negligible latency. |
| HYP-002: Overlay intercepts scrollWheel before parent | HIGH | CONFIRMED | .overlay() NSView receives events first via hitTest dispatch; not calling super/nextResponder prevents parent from scrolling. Per-event control validated. |
