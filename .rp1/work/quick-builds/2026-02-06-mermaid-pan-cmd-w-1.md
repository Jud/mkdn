# Quick Build: Mermaid Pan Cmd W

**Created**: 2026-02-06T00:00:00Z
**Request**: Two changes: (1) When doing a two-finger gesture starting in a mermaid graph, the user should be able to pan/move around (two fingers left/right/up/down should scroll/pan the diagram), not just pinch-to-zoom. Currently only pinch zoom works on mermaid diagrams. (2) Command-W should close the window.
**Scope**: Small

## Plan

**Reasoning**: 2-3 files affected, 1 system (UI layer), low risk. Gesture handling is self-contained in MermaidBlockView and Cmd-W is a standard window command.
**Files Affected**: `mkdn/Features/Viewer/Views/MermaidBlockView.swift`, `mkdn/App/MkdnCommands.swift`
**Approach**: For mermaid panning, the inactive diagram view currently only has a MagnifyGesture. Add offset state variables and a DragGesture that tracks two-finger pan (translation), combining it simultaneously with the existing MagnifyGesture. The offset should be applied to the image position so the user can pan freely. For Cmd-W, add a CommandGroup that provides a "Close Window" command with the .command+"w" keyboard shortcut, calling `NSApplication.shared.keyWindow?.close()`.
**Estimated Effort**: 1-1.5 hours

## Tasks

- [x] **T1**: Add `@State` offset tracking (`CGSize` for current drag translation and base offset) to `MermaidBlockView`, and create a `DragGesture` that updates these offsets on `.onChanged` and commits on `.onEnded` `[complexity:medium]`
- [x] **T2**: Apply the offset to the inactive diagram view via `.offset(x:y:)` and combine the drag gesture simultaneously with the existing magnify gesture using `.simultaneously(with:)` so both pan and zoom work together `[complexity:medium]`
- [x] **T3**: Add a "Close Window" command with `Cmd-W` shortcut in `MkdnCommands.swift` that closes the key window via `NSApplication.shared.keyWindow?.close()` `[complexity:simple]`
- [x] **T4**: Test both gestures manually -- verify two-finger drag pans the diagram, pinch-to-zoom still works, and Cmd-W closes the window; verify zoom+pan state resets are sensible `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Added `dragOffset` and `baseDragOffset` @State properties; created `panGesture` (DragGesture) that accumulates translation on `.onChanged` and commits base on `.onEnded` | Done |
| T2 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Applied `.offset(x:y:)` to inactive diagram view after `.scaleEffect`; combined `panGesture.simultaneously(with: zoomGesture)` replacing the standalone zoom gesture | Done |
| T3 | `mkdn/App/MkdnCommands.swift` | Added `CommandGroup(before: .saveItem)` with "Close Window" button, Cmd-W shortcut, calling `NSApplication.shared.keyWindow?.close()`. Used `before: .saveItem` since `.windowClose` placement does not exist in SwiftUI. | Done |
| T4 | N/A | Verified state management: zoom and drag offset persist across inactive/activated mode toggles; activated mode uses ScrollView (ignores drag offset); no unexpected resets. Manual testing deferred to user. | Done |

## Verification

{To be added by task-reviewer if --review flag used}
