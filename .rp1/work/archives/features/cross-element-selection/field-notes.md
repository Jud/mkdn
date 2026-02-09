# Field Notes: Cross-Element Selection

## T3: SelectableTextView

### NSTextViewportLayoutControllerDelegate is nonisolated in SDK

The `NSTextViewportLayoutControllerDelegate` protocol methods (`viewportBounds(for:)`, `configureRenderingSurfaceFor:`) are **not** marked `@MainActor` in the macOS SDK, despite being AppKit delegate methods that are always called on the main thread. This conflicts with an `@MainActor` Coordinator class.

**Solution**: Use `@preconcurrency` conformance: `@preconcurrency NSTextViewportLayoutControllerDelegate`. This defers isolation checking to runtime, which is safe because AppKit calls these methods on the main thread. This matches the project's existing pattern in `MermaidWebView.swift` (`@preconcurrency import WebKit`, `nonisolated func userContentController`).

### TextKit 2 is default on macOS 14+

`NSTextView.scrollableTextView()` produces a TextKit 2-backed text view on macOS 14+ (our minimum target). Confirmed by accessing `textView.textLayoutManager` (non-nil) and successfully setting the viewport layout controller delegate.

### Viewport Layout Controller Delegate Setup

Setting a custom `NSTextViewportLayoutControllerDelegate` on the text view's layout manager does not interfere with NSTextView's own rendering. The delegate provides an extension point for customizing layout fragment rendering surfaces, used here as the hook for entrance animations.

## T5: EntranceAnimator

### NSTextLayoutFragment does not expose a CALayer

The design assumed per-fragment `CALayer` access for direct opacity and transform animation. In practice, `NSTextLayoutFragment` does not expose a `layer` property. NSTextView renders text through its backing store (via `drawRect:`), not through individual fragment sublayers.

**Solution**: Cover-layer approach. For each fragment, a `CALayer` filled with the text view's background color is added as a sublayer at the fragment's frame. This cover layer starts opaque (hiding the text) and fades out with the stagger delay, revealing the text beneath. The visual effect is equivalent to the text fading in from opacity 0 to 1. For the upward drift, a single `CATransform3D` translation animation is applied to the text view's layer, giving all content a synchronized 8pt upward drift during the cascade. The combined visual closely matches the per-fragment SwiftUI entrance animation.

### beginEntrance must precede setAttributedString

Setting `NSTextView.textStorage?.setAttributedString()` may trigger an immediate layout pass, which calls `configureRenderingSurfaceFor` for visible fragments. If `beginEntrance()` has not been called yet, the animator's `isAnimating` flag is false and fragments miss their entrance animation. The fix is to call `beginEntrance()` before `setAttributedString()` in both `makeNSView` and `updateNSView`.

### Cover layer cleanup

Cover layers are temporary (they exist only during the entrance animation). A `Task.sleep`-based cleanup removes them after `staggerCap + fadeInDuration + 0.1s`. The cleanup also sets `isAnimating = false` so that fragments entering the viewport later (from scrolling) appear immediately without animation. The cleanup task is cancelled and re-created if a new entrance begins before the previous one completes.
