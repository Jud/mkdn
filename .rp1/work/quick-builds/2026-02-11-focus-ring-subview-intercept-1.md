# Quick Build: Focus Ring Subview Intercept

**Created**: 2026-02-11T00:00:00Z
**Request**: Replace failed WKWebView extension focus ring suppression with NoFocusRingWKWebView subclass that intercepts lazily-created internal subviews via didAddSubview and viewDidMoveToWindow. Update MermaidContainerView and FocusRingSuppressingHostingView with matching didAddSubview overrides.
**Scope**: Small

## Plan

**Reasoning**: 2 files affected (MermaidWebView.swift, OverlayCoordinator.swift), 1 system (Mermaid overlay rendering), low risk (UI-only focus ring suppression, no logic changes).
**Files Affected**: mkdn/Core/Mermaid/MermaidWebView.swift, mkdn/Features/Viewer/Views/OverlayCoordinator.swift
**Approach**: Remove the non-functional WKWebView extension override. Create a NoFocusRingWKWebView subclass that suppresses focus rings on itself and recursively on all subviews as they are lazily created by WebKit (via didAddSubview and viewDidMoveToWindow). Update MermaidContainerView with a didAddSubview override for the same recursive suppression. Add didAddSubview override to FocusRingSuppressingHostingView to complement its existing layout-based approach. Replace WKWebView instantiation with NoFocusRingWKWebView in makeNSView.
**Estimated Effort**: 1 hour

## Tasks

- [x] **T1**: Remove the `extension WKWebView` focus ring override block (lines 7-13) from MermaidWebView.swift `[complexity:simple]`
- [x] **T2**: Create `NoFocusRingWKWebView: WKWebView` subclass with focusRingType, drawFocusRingMask, focusRingMaskBounds overrides, plus didAddSubview and viewDidMoveToWindow recursive suppression `[complexity:medium]`
- [x] **T3**: Add didAddSubview override to MermaidContainerView that recursively sets focusRingType = .none on added subviews and descendants `[complexity:simple]`
- [x] **T4**: Replace `WKWebView(frame:configuration:)` with `NoFocusRingWKWebView(frame:configuration:)` in makeNSView `[complexity:simple]`
- [x] **T5**: Add didAddSubview override to FocusRingSuppressingHostingView in OverlayCoordinator.swift that recursively suppresses focus rings on added subviews `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Core/Mermaid/MermaidWebView.swift` | Removed extension WKWebView focus ring override block and MARK comment | Done |
| T2 | `mkdn/Core/Mermaid/MermaidWebView.swift` | Created `NoFocusRingWKWebView` subclass with focusRingType/.none, drawFocusRingMask (empty), focusRingMaskBounds/.zero, didAddSubview recursive suppression, viewDidMoveToWindow recursive suppression, and static suppressFocusRings helper | Done |
| T3 | `mkdn/Core/Mermaid/MermaidWebView.swift` | Added didAddSubview override to MermaidContainerView delegating to NoFocusRingWKWebView.suppressFocusRings | Done |
| T4 | `mkdn/Core/Mermaid/MermaidWebView.swift` | Replaced WKWebView instantiation with NoFocusRingWKWebView in makeNSView | Done |
| T5 | `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | Added didAddSubview override to FocusRingSuppressingHostingView calling suppressFocusRings on added subview; also fixed suppressFocusRings to set focusRingType on root view param and iterate children | Done |

## Verification

{To be added by task-reviewer if --review flag used}
