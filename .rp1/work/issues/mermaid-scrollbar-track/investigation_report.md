# Root Cause Investigation Report - mermaid-scrollbar-track

## Executive Summary
- **Problem**: Mermaid diagram WKWebViews sometimes display scrollbars with a visible bright/white track background instead of native macOS overlay scrollbar behavior (pill-only, no track).
- **Root Cause**: The HTML template (`mermaid-template.html`) contains zero `::-webkit-scrollbar` CSS rules. WebKit's default scrollbar rendering in WKWebView uses classic (non-overlay) scrollbar styling with an opaque track background, which does not match the native macOS overlay scrollbar appearance. The `body { overflow: visible; }` rule allows content overflow to trigger these default scrollbars. Additionally, Mermaid.js `foreignObject` elements within SVGs can independently trigger scrollbars with their own opaque tracks.
- **Solution**: Add `::-webkit-scrollbar` CSS rules to the HTML template to make the scrollbar track transparent and the thumb semi-transparent, adapting to dark/light themes. Alternatively (or additionally), use the modern `scrollbar-color` CSS property.
- **Urgency**: Low -- cosmetic issue, but visually jarring in dark mode.

## Investigation Process
- **Duration**: Single-pass static analysis
- **Hypotheses Tested**: 4 (see below)
- **Key Evidence**: (1) No `::-webkit-scrollbar` CSS rules anywhere in the HTML template or codebase; (2) `body { overflow: visible }` allows default WebKit scrollbars; (3) Mermaid.js uses `foreignObject` elements (9 references in mermaid.min.js), which embed HTML inside SVG and can independently produce scrollbars; (4) WKWebView has `drawsBackground=false` and `underPageBackgroundColor=.clear`, but these do not affect the WebKit-internal scrollbar track rendering.

## Root Cause Analysis

### Technical Details

**Primary cause: Missing `::-webkit-scrollbar` CSS customization**

File: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html`

The entire CSS block is:

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { background: transparent; width: 100%; }
body { overflow: visible; }
#diagram { display: block; width: 100%; }
#diagram svg { display: block; width: 100%; height: auto; }
```

There are zero `::-webkit-scrollbar`, `::-webkit-scrollbar-track`, or `::-webkit-scrollbar-thumb` rules. WebKit in WKWebView defaults to classic scrollbar rendering (not macOS overlay style), which includes an opaque light/white track background.

**Contributing cause: `foreignObject` in Mermaid SVG output**

The Mermaid configuration uses `flowchart: { htmlLabels: true }` (line 32 and 64 of the template). When `htmlLabels` is `true`, Mermaid.js renders text labels using `<foreignObject>` elements embedded inside the SVG. These `foreignObject` elements contain HTML `<div>` blocks that can independently overflow and trigger their own scrollbars with default (opaque track) styling. This is a known WebKit behavior where `foreignObject` content inherits the browser's default scrollbar style rather than respecting overlay scrollbar preferences.

**Contributing cause: `overflow: visible` on body**

Line 9 of `mermaid-template.html` sets `body { overflow: visible; }`. When the rendered SVG dimensions exceed the WKWebView's frame (e.g., during magnification/zoom or for very wide diagrams), the body can overflow and the browser will display default scrollbars.

**Non-contributing factor: WKWebView transparency settings**

File: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`, lines 64-65:

```swift
webView.setValue(false, forKey: "drawsBackground")
webView.underPageBackgroundColor = .clear
```

These settings correctly make the WKWebView's own background transparent. However, they do NOT affect the rendering of WebKit's internal scrollbar chrome. Scrollbar track/thumb colors are controlled entirely by CSS within the web content.

### Causation Chain

```
Root Cause: No ::-webkit-scrollbar CSS rules in mermaid-template.html
    |
    v
WebKit uses default classic scrollbar styling (opaque white/light track)
    |
    v
When content overflows (zoom, wide diagrams, foreignObject elements):
    |
    +---> Body overflow triggers scrollbars with visible white track
    +---> foreignObject elements inside SVG trigger their own scrollbars
    |
    v
Symptom: Bright/white scrollbar track visible, especially jarring in dark mode
```

### Why It Occurred

The original template was written with `background: transparent` on `html, body`, and the WKWebView was configured with `drawsBackground=false`. This handles the page background correctly but does not address WebKit's scrollbar rendering, which is a separate concern. The scrollbar styling was simply never added to the template CSS.

## Proposed Solutions

### 1. Recommended: Add `::-webkit-scrollbar` CSS rules to the HTML template

**File to modify**: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html`

Add the following CSS inside the existing `<style>` block:

```css
/* Overlay-style scrollbars: transparent track, semi-transparent thumb */
::-webkit-scrollbar {
    width: 8px;
    height: 8px;
}
::-webkit-scrollbar-track {
    background: transparent;
}
::-webkit-scrollbar-thumb {
    background: rgba(128, 128, 128, 0.3);
    border-radius: 4px;
}
::-webkit-scrollbar-thumb:hover {
    background: rgba(128, 128, 128, 0.5);
}
::-webkit-scrollbar-corner {
    background: transparent;
}
```

This uses `rgba` with neutral gray and low opacity, which naturally adapts to both dark and light backgrounds by being semi-transparent. The transparent track eliminates the visible white background.

**Effort**: Minimal (add ~15 lines of CSS to one file).
**Risk**: Very low -- these are standard WebKit CSS pseudo-elements.
**Pros**: Simple, no Swift code changes, works for both body and foreignObject scrollbars.
**Cons**: Does not use the exact macOS system overlay scrollbar rendering (approximation).

### 2. Alternative A: Hide scrollbars entirely with `overflow: hidden`

Change `body { overflow: visible; }` to `body { overflow: hidden; }` and add `#diagram svg { overflow: hidden; }`.

**Effort**: Minimal (change 1-2 CSS rules).
**Risk**: Medium -- this would prevent scrolling within the WKWebView entirely when focused, which conflicts with the current design that allows two-finger pan within focused diagrams.
**Pros**: Completely eliminates scrollbar appearance.
**Cons**: Breaks the pan/scroll interaction model for focused diagrams. Not recommended as a standalone fix.

### 3. Alternative B: Use `scrollbar-color` CSS property (modern approach)

```css
html {
    scrollbar-color: rgba(128, 128, 128, 0.3) transparent;
}
```

**Effort**: Minimal (1 line of CSS).
**Risk**: Low -- `scrollbar-color` is supported in WebKit/Safari 16+. However, it does NOT affect `foreignObject` elements in the same way as `::-webkit-scrollbar` pseudo-elements do.
**Pros**: Standards-based approach.
**Cons**: Less control over sizing and hover states. May not cover `foreignObject` scrollbars. WebKit support for this property inside `foreignObject` is inconsistent.

### 4. Alternative C: Combined approach (recommended if thoroughness is desired)

Use both `::-webkit-scrollbar` rules (Solution 1) AND `overflow: hidden` on `foreignObject` descendants specifically:

```css
/* Solution 1 scrollbar rules here... */

/* Additionally suppress foreignObject scrollbars */
foreignObject div {
    overflow: hidden !important;
}
```

This would handle both the body-level scrollbars (styled transparently) and the foreignObject-level scrollbars (suppressed, since label text should not need to scroll).

**Effort**: Minimal.
**Risk**: Low -- foreignObject labels are short text; suppressing their overflow is safe.

## Prevention Measures

1. When adding WKWebView-based content, always include `::-webkit-scrollbar` CSS rules as part of the baseline template, similar to how `background: transparent` is standard practice.
2. Consider adding a visual QA checklist item for dark mode scrollbar appearance when any WKWebView content is modified.
3. When using Mermaid.js with `htmlLabels: true`, be aware that `foreignObject` elements can independently produce scrollbars and plan CSS accordingly.

## Evidence Appendix

### Evidence 1: HTML Template CSS (no scrollbar rules)

**File**: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html`, lines 6-12

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { background: transparent; width: 100%; }
body { overflow: visible; }
#diagram { display: block; width: 100%; }
#diagram svg { display: block; width: 100%; height: auto; }
```

No `::-webkit-scrollbar` rules present. `overflow: visible` allows default scrollbar rendering.

### Evidence 2: WKWebView transparency configuration

**File**: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidWebView.swift`, lines 61-66

```swift
let webView = WKWebView(frame: container.bounds, configuration: configuration)
webView.navigationDelegate = context.coordinator
webView.isHidden = false
webView.setValue(false, forKey: "drawsBackground")
webView.underPageBackgroundColor = .clear
webView.allowsMagnification = true
```

These settings make the WKWebView background transparent but do not control scrollbar styling. Note `allowsMagnification = true` enables pinch-to-zoom which can cause content to exceed the viewport, triggering scrollbars.

### Evidence 3: Mermaid.js uses foreignObject

**File**: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid.min.js` -- 9 references to `foreignObject` in the minified source.

**File**: `/Users/jud/Projects/mkdn/mkdn/Resources/mermaid-template.html`, lines 32, 64 -- `flowchart: { htmlLabels: true }` enables foreignObject-based label rendering.

### Evidence 4: Grep confirms no scrollbar CSS exists anywhere in codebase

```
$ grep -r "webkit-scrollbar" mkdn/  -> No files found
$ grep -r "scrollbar" mkdn/         -> No files found
```

### Evidence 5: Mermaid.js version

Version 11.12.2 (extracted from mermaid.min.js). This version uses `foreignObject` for HTML labels in flowcharts.
