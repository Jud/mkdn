# Field Notes: Cross-Element Selection

## T3: SelectableTextView

### NSTextViewportLayoutControllerDelegate is nonisolated in SDK

The `NSTextViewportLayoutControllerDelegate` protocol methods (`viewportBounds(for:)`, `configureRenderingSurfaceFor:`) are **not** marked `@MainActor` in the macOS SDK, despite being AppKit delegate methods that are always called on the main thread. This conflicts with an `@MainActor` Coordinator class.

**Solution**: Use `@preconcurrency` conformance: `@preconcurrency NSTextViewportLayoutControllerDelegate`. This defers isolation checking to runtime, which is safe because AppKit calls these methods on the main thread. This matches the project's existing pattern in `MermaidWebView.swift` (`@preconcurrency import WebKit`, `nonisolated func userContentController`).

### TextKit 2 is default on macOS 14+

`NSTextView.scrollableTextView()` produces a TextKit 2-backed text view on macOS 14+ (our minimum target). Confirmed by accessing `textView.textLayoutManager` (non-nil) and successfully setting the viewport layout controller delegate.

### Viewport Layout Controller Delegate Setup

Setting a custom `NSTextViewportLayoutControllerDelegate` on the text view's layout manager does not interfere with NSTextView's own rendering. The delegate provides an extension point for customizing layout fragment rendering surfaces, used here as the hook for entrance animations (T5).
