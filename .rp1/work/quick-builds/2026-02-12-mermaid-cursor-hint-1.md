# Quick Build: Mermaid Cursor Hint

**Created**: 2026-02-12T00:00:00Z
**Request**: Remove the background and background hover highlight from mermaid diagrams and instead change the cursor to indicate the user should click to interact with the mermaid diagram
**Scope**: Small

## Plan

**Reasoning**: Single file change (MermaidBlockView.swift), single system (Viewer), low risk -- removing two visual modifiers and adding a cursor change on hover. The codebase already uses `NSCursor.pointingHand.push()`/`NSCursor.pop()` in TheOrbView.swift, so the pattern is established.

**Files Affected**:
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift`

**Approach**: Remove the `.background(colors.backgroundSecondary)` and `.hoverBrightness()` modifiers from `MermaidBlockView.body`. Add an `.onHover` handler that pushes `NSCursor.pointingHand` when the cursor enters the unfocused diagram and pops it when the cursor leaves. When the diagram is focused (interactive mode), the cursor should revert to default since the user is already interacting. This follows the existing pattern from `TheOrbView.swift` line 93-97.

**Estimated Effort**: 0.5 hours

## Tasks

- [x] **T1**: Remove `.background(colors.backgroundSecondary)` and `.hoverBrightness()` from `MermaidBlockView.body` in `mkdn/Features/Viewer/Views/MermaidBlockView.swift` `[complexity:simple]`
- [x] **T2**: Add `.onHover` handler to `MermaidBlockView.body` that pushes `NSCursor.pointingHand` when hovering over an unfocused diagram and pops it on exit, following the pattern from `TheOrbView.swift` `[complexity:simple]`
- [x] **T3**: Verify build succeeds with `swift build` and lint passes with SwiftLint `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Removed `.background(colors.backgroundSecondary)` and `.hoverBrightness()` modifiers from `body` | Done |
| T2 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Added `.onHover` with `NSCursor.pointingHand` push/pop gated by `!isFocused`, state-tracked via `isCursorPushed` flag with `onChange(of: isFocused)` to pop cursor on focus activation | Done |
| T3 | -- | `swift build` passes, SwiftLint 0 violations | Done |

## Verification

{To be added by task-reviewer if --review flag used}
