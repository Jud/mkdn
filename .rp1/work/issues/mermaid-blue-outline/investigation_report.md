# Root Cause Investigation Report - mermaid-blue-outline

## Executive Summary
- **Problem**: A bright blue outline/border appears around mermaid diagram containers, unthemed and persistent despite 4 fix attempts targeting focus rings at different layers.
- **Root Cause**: Most likely the macOS system keyboard navigation focus indicator drawn by the window server, triggered by the `.focusable()` SwiftUI modifier on MermaidBlockView. Two SwiftUI internal bridge views (`PlatformViewHost`, `_NSInheritedView`) have `focusRingType = .default` and are NOT accessible to the developer, making them immune to the applied `.none` overrides.
- **Solution**: Remove `.focusable()` from MermaidBlockView and implement focus management entirely through the AppKit layer (MermaidContainerView), or suppress focus effects by overriding `drawFocusRingMask()` on a custom NSHostingView subclass.
- **Urgency**: Medium -- visual defect affecting theming consistency but not functionality.

## Investigation Process
- **Duration**: Extended investigation with runtime debugging
- **Hypotheses Tested**:
  1. NSView focus ring on WKWebView/container -> RULED OUT (focusRingType=.none confirmed at runtime)
  2. CALayer border on any view -> RULED OUT (all borderWidth=0 confirmed)
  3. NSScrollView borderType -> RULED OUT (borderType=.noBorder confirmed)
  4. WKWebView internal scroll view border -> RULED OUT (no internal scroll views found)
  5. HTML/CSS outline from web content -> RULED OUT (*:focus { outline: none } present, pixel analysis shows no blue)
  6. SwiftUI internal bridge view focus ring -> STRONGEST REMAINING (PlatformViewHost and _NSInheritedView have focusRingType=.default)
  7. macOS window server focus indicator -> PROBABLE (not visible in programmatic capture, suggesting compositor-level drawing)
- **Key Evidence**: Runtime view hierarchy and layer tree dumps, pixel-level screenshot analysis

## Root Cause Analysis

### Technical Details

The mermaid diagram view hierarchy (from innermost to outermost):

```
WKWebView [focusRingType=.none]
  inside MermaidContainerView [focusRingType=.none]
    inside PlatformViewHost [focusRingType=.default] <-- INACCESSIBLE
      inside _NSInheritedView [focusRingType=.default] <-- INACCESSIBLE
        inside NSHostingView [focusRingType=.none]
```

**The two intermediate SwiftUI bridge views (`PlatformViewHost<PlatformViewRepresentableAdaptor<MermaidWebView>>` and `_NSInheritedView`) have `focusRingType = .default`.** These are private SwiftUI framework classes that the developer cannot directly access or configure. Setting `.focusRingType = .none` on the enclosing NSHostingView and inner WKWebView/MermaidContainerView does NOT propagate to these intermediates.

The `.focusable()` SwiftUI modifier on MermaidBlockView registers the view in SwiftUI's focus system. This causes:
1. The NSHostingView (and its SwiftUI-internal children) to participate in the AppKit responder chain for focus
2. On macOS 14+/15, the system may draw a focus indicator around views registered as focusable
3. `.focusEffectDisabled()` suppresses the SwiftUI-level focus effect but does NOT suppress the AppKit-level focus ring that the inaccessible bridge views may draw

### Causation Chain

```
.focusable() modifier on MermaidBlockView
  -> SwiftUI registers view in focus system
    -> PlatformViewHost and _NSInheritedView created with focusRingType = .default
      -> When any focus event occurs (keyboard nav, tab, window activation)
        -> macOS draws system blue focus ring around the view with .default focusRingType
          -> Blue outline visible around mermaid container
```

### Why Previous Fixes Failed

1. **`.focusEffectDisabled()`** - Suppresses SwiftUI's own focus effect drawing, but does NOT prevent AppKit's focus ring on the private bridge views.
2. **`webView.focusRingType = .none`** - Sets the property on the WKWebView, but the ring is drawn by a PARENT bridge view, not the WKWebView itself.
3. **`container.focusRingType = .none`** - Same issue -- the bridge views above the container still have `.default`.
4. **`hostingView.focusRingType = .none`** - The NSHostingView IS set to `.none`, but the children bridge views are created by SwiftUI and revert to `.default`.
5. **`*:focus { outline: none; }`** - CSS focus outline is separate from AppKit focus ring; this only affects web content rendering.

### Why It Was Not Reproduced in Programmatic Capture

The blue outline was NOT visible in CGWindowListCreateImage captures during this investigation. This suggests:
1. The outline may only appear under specific user interaction conditions not triggered during automated testing
2. The outline may be drawn at the window server/compositor level in a way that is not captured by standard screen capture APIs under certain conditions
3. The user's system may have macOS Keyboard Navigation enabled (System Settings > Accessibility > Keyboard), which causes more prominent focus indicators

### Environment Note

The investigation was conducted on macOS 15.5 (Darwin 24.5.0). The user's macOS accessibility settings and keyboard navigation preferences are unknown and could affect reproducibility.

## Proposed Solutions

### 1. Recommended: Remove `.focusable()` and Use AppKit-Level Focus (Effort: Low, Risk: Low)

Remove `.focusable()` and `.focusEffectDisabled()` from MermaidBlockView. Instead, manage focus entirely through the AppKit responder chain:

- Override `acceptsFirstResponder` on `MermaidContainerView` to return `true` when `allowsInteraction` is `true`
- Use `window?.makeFirstResponder(containerView)` for focus activation instead of SwiftUI's `@FocusState`
- Keep the custom `focusBorder` overlay for visual feedback (it uses themed colors)
- This eliminates the SwiftUI focus system entirely, preventing bridge views from participating

**Pros**: Eliminates root cause, no dependency on SwiftUI focus system behavior.
**Cons**: Requires reimplementing focus tracking logic in AppKit.

### 2. Alternative: Custom NSHostingView Subclass (Effort: Medium, Risk: Medium)

Create a custom `MermaidHostingView: NSHostingView` subclass that:
- Overrides `drawFocusRingMask()` to return an empty path
- Overrides `focusRingMaskBounds` to return `.zero`
- Recursively sets `focusRingType = .none` on all subviews after layout

```swift
class MermaidHostingView<Content: View>: NSHostingView<Content> {
    override func drawFocusRingMask() { /* empty */ }
    override var focusRingMaskBounds: NSRect { .zero }

    override func layout() {
        super.layout()
        suppressFocusRings(in: self)
    }

    private func suppressFocusRings(in view: NSView) {
        view.focusRingType = .none
        for subview in view.subviews {
            suppressFocusRings(in: subview)
        }
    }
}
```

**Pros**: Preserves SwiftUI focus system for keyboard navigation.
**Cons**: Fragile -- depends on SwiftUI's internal view hierarchy not changing between macOS versions. The `layout()` override may have performance implications.

### 3. Alternative: Global Focus Ring Suppression via NSAppearance (Effort: Low, Risk: High)

Globally override the focus ring color or suppress focus rings at the window level. NOT recommended as it would affect ALL focusable views in the app.

## Prevention Measures

1. **Avoid mixing SwiftUI `.focusable()` with NSViewRepresentable content** -- The SwiftUI focus system creates intermediary AppKit views with default focus ring behavior that cannot be directly controlled. When precise focus management is needed for NSViewRepresentable content, use AppKit's responder chain directly.

2. **Test with macOS Keyboard Navigation enabled** -- Enable "Keyboard navigation" in System Settings > Accessibility > Keyboard during QA testing. This setting causes macOS to draw more prominent focus indicators and is likely what the user has enabled.

3. **Add visual verification test for mermaid focus ring absence** -- The existing vision verification workflow could include a specific check for unexpected blue outlines around mermaid containers.

## Evidence Appendix

### Runtime View Hierarchy (at renderComplete)
See: `evidence/hierarchy-dump.txt`

### Layer Tree After Full Render
See: `evidence/layer-tree-rendered.txt`

### Pixel-Level Screenshot Analysis
See: `evidence/pixel-analysis.txt`

### Key Code Locations
- `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift` lines 42-44: `.focusable()` + `.focusEffectDisabled()` + `.focused()` -- the root cause trigger
- `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift` lines 67, 70: `focusRingType = .none` on WKWebView and container -- existing mitigations that are insufficient
- `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift` line 237: `hostingView.focusRingType = .none` -- existing mitigation that is insufficient
- `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift` lines 147-164: Custom focus border overlay -- correctly themed but separate from the system-drawn blue ring
