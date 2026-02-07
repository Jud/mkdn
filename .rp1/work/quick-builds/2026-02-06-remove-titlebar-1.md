# Quick Build: Remove Titlebar

**Created**: 2026-02-06T00:00:00Z
**Request**: Remove the top open/close/minimize title bar. Make this an absolute minimal window -- no traffic lights, no title bar, just the content. The app is a SwiftUI macOS app launched from CLI via swift run. The window is defined in mkdnEntry/main.swift using WindowGroup and the content is in ContentView.swift.
**Scope**: Small

## Plan

**Reasoning**: This affects 1-2 files (mkdnEntry/main.swift and possibly ContentView.swift), touches 1 system (window chrome), and is low risk since it is purely a UI styling change with no logic impact.

**Files Affected**:
- `mkdnEntry/main.swift` -- add window style modifiers to WindowGroup and/or NSWindow configuration
- `mkdn/App/ContentView.swift` -- potentially add container background or edge-to-edge adjustments

**Approach**: Use SwiftUI's `.windowStyle(.hiddenTitleBar)` modifier on the WindowGroup scene to remove the title bar. To also hide the traffic light buttons (close/minimize/zoom), use an `NSWindow` customization approach -- either via an `NSViewRepresentable` helper or `onAppear` with `NSApplication.shared.windows` -- to set `styleMask` and `titlebarAppearsTransparent`, and hide the standardWindowButton controls. The content already has `.frame(minWidth: 600, minHeight: 400)` so it will fill edge-to-edge. Since this is a CLI-launched app with no toolbar, the hidden title bar approach is clean and minimal.

**Estimated Effort**: 0.5-1 hour

## Tasks

- [x] **T1**: Add `.windowStyle(.hiddenTitleBar)` modifier to the WindowGroup in `mkdnEntry/main.swift` to remove the visible title bar `[complexity:simple]`
- [x] **T2**: Create a `WindowAccessor` NSViewRepresentable utility that finds the hosting NSWindow and hides traffic light buttons (close/minimize/zoom) via `standardWindowButton(.closeButton)?.isHidden = true` and sets `titlebarAppearsTransparent = true`, `isMovableByWindowBackground = true` `[complexity:medium]`
- [x] **T3**: Apply the WindowAccessor as a background modifier in ContentView or the WindowGroup content so it activates when the window appears `[complexity:simple]`
- [x] **T4**: Verify the window is still draggable, resizable, and closable via keyboard shortcut (Cmd+Q) after removing chrome; adjust `styleMask` if needed `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdnEntry/main.swift` | Added `.windowStyle(.hiddenTitleBar)` modifier to WindowGroup scene | Done |
| T2 | `mkdn/UI/Components/WindowAccessor.swift` | Created NSViewRepresentable with custom NSView subclass that configures NSWindow in `viewDidMoveToWindow` -- hides all three traffic light buttons, sets transparent titlebar, enables drag-by-background | Done |
| T3 | `mkdn/App/ContentView.swift` | Applied `.background(WindowAccessor())` after the `.frame` modifier so it activates once the window is available | Done |
| T4 | (verification only) | Build succeeds, all tests pass; `.hiddenTitleBar` preserves resizable/closable styleMask bits, `isMovableByWindowBackground` enables drag from content area, Cmd+Q/Cmd+W work via menu commands unaffected by hidden buttons | Done |

## Verification

{To be added by task-reviewer if --review flag used}
