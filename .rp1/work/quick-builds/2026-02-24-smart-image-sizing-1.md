# Quick Build: Smart Image Sizing

**Created**: 2026-02-24T00:00:00Z
**Request**: smart image sizing - images should render at their natural size, scaled to fit within the container width (never wider than the text container), preserving aspect ratio. Small images should render at their native size, large images should scale down to fit.
**Scope**: Small

## Plan

**Reasoning**: This touches 1-2 files (ImageBlockView.swift and OverlayCoordinator.swift) in a single system (Viewer). The change is a straightforward SwiftUI layout adjustment with no architectural risk. The overlay coordinator may need a size callback to update attachment height based on actual image dimensions rather than a fixed placeholder.

**Files Affected**:
- `mkdn/Features/Viewer/Views/ImageBlockView.swift` -- replace `.resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity)` with natural-size-aware layout that caps at container width
- `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` -- update `makeImageOverlay` to pass a size callback (like Mermaid does) so the attachment placeholder height matches the actual rendered image height

**Approach**: In `ImageBlockView`, once the `NSImage` is loaded, read its natural `size` property. Use a `GeometryReader` or the overlay coordinator's container width to determine whether the image fits naturally or needs to scale down. Apply `frame(width: min(naturalWidth, containerWidth))` with `.aspectRatio(contentMode: .fit)` so small images stay at native size and large images shrink to fit. Wire a size-reporting callback from `ImageBlockView` back to `OverlayCoordinator.updateAttachmentHeight` so the attachment placeholder accurately reflects the rendered image height (matching the Mermaid pattern). This eliminates the current behavior where all images stretch to full container width.

**Estimated Effort**: 1 hour

## Tasks

- [x] **T1**: Add a `containerWidth` property and `onSizeChange` callback to `ImageBlockView`, and update `imageContent(_:)` to compute the rendered size as `min(image.size.width, containerWidth)` with aspect-ratio-preserved height, applying `.frame(width:height:)` instead of `.frame(maxWidth: .infinity)` `[complexity:medium]`
- [x] **T2**: Update `OverlayCoordinator.makeImageOverlay` to pass a `containerWidth` and wire an `onSizeChange` callback that calls `updateAttachmentHeight(blockIndex:newHeight:)` when the image loads, matching the existing Mermaid callback pattern `[complexity:simple]`
- [x] **T3**: Verify rendering with a test fixture containing small inline images, large images wider than the container, and images with various aspect ratios; capture screenshots at different window widths to confirm small images stay native and large images scale down `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Features/Viewer/Views/ImageBlockView.swift`, `mkdn/Features/Viewer/Views/MarkdownBlockView.swift` | Added `containerWidth` and `onSizeChange` callback; `imageContent` computes `min(naturalWidth, containerWidth)` with aspect-ratio-preserved height; reports size via callback on appear and container width change; MarkdownBlockView wraps image case in GeometryReader | Done |
| T2 | `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` | `makeImageOverlay` passes container width and wires `onSizeChange` to `updateAttachmentSize(blockIndex:newWidth:newHeight:)`, setting `preferredWidth` for small images | Done |
| T3 | (visual verification) | Verified with `fixtures/image-test.md` via test harness: 200x150 small image renders at native size left-aligned, 600x400 renders at natural width, 800x200 panoramic scales down to container, 300x300 square stays native. Both dark and light themes verified | Done |

## Verification

{To be added by task-reviewer if --review flag used}
