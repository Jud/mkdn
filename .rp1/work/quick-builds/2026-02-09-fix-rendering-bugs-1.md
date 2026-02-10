# Quick Build: Fix Rendering Bugs

**Created**: 2026-02-09T00:00:00Z
**Request**: Fix two rendering bugs: (1) Mermaid diagrams render at thumbnail size because NSTextAttachment bounds are fixed at 1pt width/200pt height and never update after WKWebView renders -- wire the sizeReport callback through MermaidBlockView to OverlayCoordinator.updateAttachmentHeight(), add ResizeObserver in mermaid-template.html, fix updateAttachmentHeight to update width. (2) Excessive vertical spacing between elements -- reduce lineSpacing default from 4pt to 2pt, increase heading paragraphSpacingBefore to match PRD targets, reduce attachmentPlaceholderHeight from 200pt to 100pt.
**Scope**: Medium

## Plan

**Reasoning**: 5-6 files across 2 systems (Mermaid rendering pipeline and Markdown text storage/layout). The Mermaid fix requires wiring an existing but orphaned update method and adding a JavaScript ResizeObserver. The spacing fix requires tuning constants in the text storage builder. Risk is medium -- changes touch the text layout system but are well-scoped with clear root causes identified in investigation reports.
**Files Affected**:
- `mkdn/Features/Viewer/Views/OverlayCoordinator.swift` (add onSizeChange closure plumbing, fix updateAttachmentHeight width)
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift` (add onSizeChange callback parameter)
- `mkdn/Core/Mermaid/MermaidWebView.swift` (no changes needed -- sizeReport already updates bindings)
- `mkdn/Resources/mermaid-template.html` (add ResizeObserver for re-sending sizeReport)
- `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` (reduce lineSpacing default, reduce attachmentPlaceholderHeight)
- `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift` (increase heading paragraphSpacingBefore values)
**Approach**: Bug 1 is fixed by adding an `onSizeChange` closure to MermaidBlockView that fires when renderedHeight/renderedAspectRatio change, passing it from OverlayCoordinator.makeMermaidOverlay() to call updateAttachmentHeight() with the correct blockIndex and computed height (containerWidth * aspectRatio). The updateAttachmentHeight method is also fixed to update width alongside height. A ResizeObserver is added in the HTML template to re-send sizeReport when the viewport resizes. Bug 2 is fixed by adjusting spacing constants: lineSpacing 4->2, attachmentPlaceholderHeight 200->100, and heading paragraphSpacingBefore increased to PRD-aligned values (28pt H1, 20pt H2, 14pt H3+) that account for font metrics to produce visual gaps closer to PRD targets of 48pt, 32pt, 24pt.
**Estimated Effort**: 3-5 hours

## Tasks

- [x] **T1**: Wire mermaid size feedback loop: Add `onSizeChange: ((CGFloat, CGFloat) -> Void)?` closure to `MermaidBlockView` that fires via `.onChange(of: renderedHeight)` and `.onChange(of: renderedAspectRatio)`. In `OverlayCoordinator.makeMermaidOverlay()`, pass the blockIndex and a closure that calls `updateAttachmentHeight(blockIndex:newHeight:)` with the height computed from container width and aspect ratio. Fix `updateAttachmentHeight` to set width to container width instead of preserving the 1pt placeholder width. `[complexity:medium]`
- [x] **T2**: Add ResizeObserver to mermaid-template.html: After initial `render()`, install a `ResizeObserver` on the SVG element (or `#diagram` container) that re-sends `sizeReport` via `window.webkit.messageHandlers.sizeReport.postMessage()` whenever the observed element's dimensions change. Debounce with `requestAnimationFrame` to avoid excessive messages. Also re-send sizeReport after `reRenderWithTheme`. `[complexity:simple]`
- [x] **T3**: Fix vertical spacing constants: In `MarkdownTextStorageBuilder.swift`, reduce `lineSpacing` default from 4 to 2 in `makeParagraphStyle()` and reduce `attachmentPlaceholderHeight` from 200 to 100. In `MarkdownTextStorageBuilder+Blocks.swift`, increase heading `paragraphSpacingBefore` from 8/4 to 28/20/14 (H1/H2/H3+) to produce visual gaps closer to PRD targets (48pt, 32pt, 24pt) after accounting for font metrics. `[complexity:simple]`
- [x] **T4**: Update MermaidBlockView initial renderedHeight to match new placeholder: Change `@State private var renderedHeight: CGFloat = 200` to `= 100` to match the reduced `attachmentPlaceholderHeight`. Verify the loading state frame (`minHeight: 100, maxHeight: 100`) is consistent. `[complexity:simple]`
- [x] **T5**: Build, lint, and verify: Run `swift build`, `swiftlint lint`, and `swiftformat .` to ensure all changes compile and pass linting. Run `swift test` to verify no regressions in existing tests. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `MermaidBlockView.swift`, `OverlayCoordinator.swift` | Added `onSizeChange` closure to MermaidBlockView; wired in OverlayCoordinator to call `updateAttachmentHeight` with computed height (containerWidth * aspectRatio); fixed `updateAttachmentHeight` to set width to container width | Done |
| T2 | `mermaid-template.html` | Extracted `sendSizeReport()` helper; added `installResizeObserver()` with RAF debounce on SVG/container; called after initial render and re-render | Done |
| T3 | `MarkdownTextStorageBuilder.swift`, `MarkdownTextStorageBuilder+Blocks.swift` | Reduced lineSpacing default 4->2, attachmentPlaceholderHeight 200->100; heading paragraphSpacingBefore to 28/20/14 for H1/H2/H3+ | Done |
| T4 | `MermaidBlockView.swift` | Changed initial renderedHeight from 200 to 100 (combined with T1 edit); loading frame already used minHeight/maxHeight 100 | Done |
| T5 | (none) | Build succeeds, lint clean on modified files, all unit tests pass; pre-existing animation harness failures unrelated | Done |

## Verification

{To be added by task-reviewer if --review flag used}
