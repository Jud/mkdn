# Quick Build: Escape Dismiss Find Pill

**Created**: 2026-02-15T00:00:00Z
**Request**: cmd f find pill should hide when you hit escape
**Scope**: Small

## Plan

**Reasoning**: The find pill already handles Escape via SwiftUI `.onKeyPress(.escape)` in `FindBarView`, but only when the TextField has focus. If the user clicks into the document (the `CodeBlockBackgroundTextView` NSTextView), focus leaves the SwiftUI TextField and Escape keystrokes go to AppKit, which does not forward them to dismiss the find bar. This is a 1-file fix (2 files max) with low risk.

**Files Affected**:
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` -- override `cancelOperation(_:)` to dismiss find bar when visible
- `mkdn/Features/Viewer/Views/SelectableTextView.swift` -- pass `FindState` reference to the text view so it can dismiss

**Approach**: Override `cancelOperation(_:)` (the standard Cocoa action method dispatched by NSResponder for the Escape key) in `CodeBlockBackgroundTextView`. When the find bar is visible, call `findState.dismiss()` wrapped in the quickFade animation. This requires giving the text view a weak reference to the `FindState`. The coordinator in `SelectableTextView` already has access to `FindState` and already sets up the text view -- it will assign the reference there.

**Estimated Effort**: 0.5 hours

## Tasks

- [x] **T1**: Add a `weak var findState: FindState?` property to `CodeBlockBackgroundTextView` so it can query and dismiss the find bar `[complexity:simple]`
- [x] **T2**: Override `cancelOperation(_:)` in `CodeBlockBackgroundTextView` to check `findState?.isVisible` and call `findState?.dismiss()` with quickFade animation, falling through to `super` when the find bar is not visible `[complexity:simple]`
- [x] **T3**: Wire up the `findState` reference in `SelectableTextView.Coordinator` -- set `textView.findState = findState` during `makeNSView` and `updateNSView` `[complexity:simple]`
- [x] **T4**: Verify the existing `.onKeyPress(.escape)` in `FindBarView` still works when the TextField is focused (no regression), and that Escape from the NSTextView also dismisses the pill `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `CodeBlockBackgroundTextView.swift` | Added `weak var findState: FindState?` property | Done |
| T2 | `CodeBlockBackgroundTextView.swift` | Override `cancelOperation(_:)` -- dismiss with quickFade when find bar visible, fall through to super otherwise | Done |
| T3 | `SelectableTextView.swift` | Set `textView.findState = findState` in both `makeNSView` and `updateNSView` | Done |
| T4 | (verification) | Confirmed `.onKeyPress(.escape)` in FindBarView captures Escape at SwiftUI level when TextField focused; `cancelOperation(_:)` only fires when NSTextView has focus -- mutually exclusive paths, no regression | Done |

## Verification

{To be added by task-reviewer if --review flag used}
