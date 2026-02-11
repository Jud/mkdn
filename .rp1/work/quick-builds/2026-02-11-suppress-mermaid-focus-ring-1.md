# Quick Build: Suppress Mermaid Focus Ring

**Created**: 2026-02-11T12:00:00-06:00
**Request**: Suppress the macOS blue focus ring on Mermaid diagram WKWebViews using the NSView extension pattern (proven for NSTextField). Add an extension on WKWebView that overrides focusRingType to always return .none. Also add clipsToBounds = true and wantsLayer = true on MermaidContainerView as a complementary measure (approach #2, backed by Apple QA1785).
**Scope**: Small

## Plan

**Reasoning**: Single file change (MermaidWebView.swift), single system (Mermaid rendering), low risk (additive extension + 2 property assignments, no behavioral change to existing logic). The file already sets focusRingType = .none on instances (lines 67, 70), but the class-level extension ensures all WKWebView subviews also inherit the override, which is the key difference.
**Files Affected**: `mkdn/Core/Mermaid/MermaidWebView.swift`
**Approach**: Add a WKWebView extension at the top of MermaidWebView.swift that overrides focusRingType at the class level to always return .none. This uses the same proven pattern already working for NSTextField elsewhere. Then set clipsToBounds = true and wantsLayer = true on MermaidContainerView in makeNSView to prevent focus rings from rendering outside the layer-backed view boundary (Apple QA1785). The existing instance-level focusRingType = .none assignments on lines 67 and 70 can be removed since the extension makes them redundant.
**Estimated Effort**: 0.5 hours

## Tasks

- [x] **T1**: Add `extension WKWebView` with `open override var focusRingType: NSFocusRingType { get { .none } set {} }` near the top of MermaidWebView.swift (after imports, before MermaidContainerView). Remove the now-redundant instance-level `focusRingType = .none` assignments on both webView and container. `[complexity:simple]`
- [x] **T2**: In `makeNSView`, set `container.wantsLayer = true` and `container.clipsToBounds = true` on the MermaidContainerView instance as a complementary measure to clip any focus rings that internal WKWebView subviews might draw. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Core/Mermaid/MermaidWebView.swift` | Added `extension WKWebView` with class-level `focusRingType` override returning `.none`; removed redundant instance-level assignments on webView and container. Added `swiftlint:disable:next override_in_extension` since the extension approach is intentional (covers internal WKWebView subviews). | Done |
| T2 | `mkdn/Core/Mermaid/MermaidWebView.swift` | Set `container.wantsLayer = true` and `container.clipsToBounds = true` in `makeNSView` to clip focus rings at the layer boundary (Apple QA1785) | Done |

## Verification

{To be added by task-reviewer if --review flag used}
