# Root Cause Investigation Report - cmd-w-broken

## Executive Summary
- **Problem**: Cmd+W does not close the application window
- **Root Cause**: `WindowAccessor.configureWindow` removes `.titled` from the window's style mask, which causes `NSWindow.performClose(_:)` to silently fail because there is no close button to simulate clicking
- **Solution**: Replace `performClose(nil)` with `close()` in both the local event monitor (AppDelegate) and the Close menu item (MkdnCommands)
- **Urgency**: High -- core user interaction is broken; fix is trivial (two one-line changes)

## Investigation Process
- **Duration**: ~45 minutes
- **Hypotheses Tested**:
  1. `setSelectedRanges` override interferes with responder chain -- **REJECTED** (the override only calls a handler after `super`, does not consume events)
  2. `selectionDragHandler` closure creates retain cycle or state corruption -- **REJECTED** (weak capture, only updates NSView display)
  3. Mermaid escape key monitor consumes Cmd+W -- **REJECTED** (guard filters on keyCode 53 only)
  4. `performClose(nil)` fails on untitled windows -- **CONFIRMED** (root cause)
  5. Recent `setSelectedRanges` changes caused the regression -- **REJECTED** (the actual breaking change was `WindowAccessor.remove(.titled)` in commit 3a7e760, not the selection changes)

- **Key Evidence**:
  1. Runtime test via AppleScript confirmed Close menu item fires but window does not close
  2. Git archaeology shows `remove(.titled)` introduced in commit 3a7e760 (2026-02-19), four days after the Cmd-W fix in commit ad0ae5d (2026-02-15)
  3. At the time of the Cmd-W fix, WindowAccessor only hid title bar buttons individually while keeping `.titled` in the style mask

## Root Cause Analysis

### Technical Details

**Location**: Two call sites both use `performClose(nil)`:

1. `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift` line 44:
   ```swift
   NSApp.keyWindow?.performClose(nil)
   ```

2. `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift` line 41:
   ```swift
   NSApp.keyWindow?.performClose(nil)
   ```

**Breaking change location**: `/Users/jud/Projects/mkdn/mkdn/UI/Components/WindowAccessor.swift` line 37:
```swift
window.styleMask.remove(.titled)
```

### Causation Chain

1. **Root cause**: `WindowAccessor.configureWindow` calls `window.styleMask.remove(.titled)` on the hosting NSWindow
2. Removing `.titled` eliminates the title bar and all its standard window buttons (close, minimize, zoom)
3. `NSWindow.performClose(_:)` simulates clicking the close button -- per Apple documentation: "If the window doesn't have a close button or the close button is disabled and the window's delegate doesn't implement `windowShouldClose:`, the system emits the alert sound"
4. The window has no close button (because `.titled` was removed) and no `NSWindowDelegate` implementing `windowShouldClose:`
5. Therefore `performClose(nil)` silently fails (may beep)
6. Both the local event monitor (AppDelegate) and the Close menu item (MkdnCommands) call `performClose(nil)`, so neither path works
7. The local event monitor additionally returns `nil` (consuming the key event), preventing any fallback handling

### Why It Occurred

The Cmd-W fix (commit ad0ae5d) was written when `WindowAccessor` only hid title bar buttons visually while keeping `.titled` in the style mask. Four days later, commit 3a7e760 changed the approach to completely remove `.titled` for "true chromeless window" behavior (to fix a title bar compositing layer covering scrolled content). This commit did not update the close mechanism from `performClose` to `close()`.

### Why the User's Initial Hypothesis Was Wrong

The user suspected the `setSelectedRanges` override or `selectionDragHandler` closure was the cause. This is understandable because:
- The selection changes are recent and visible in `git status`
- The timing roughly correlated with noticing the bug
- Selection/responder chain interactions are a plausible failure mode for keyboard shortcuts

However, the actual breaking change (removing `.titled`) happened earlier, in an unrelated commit. The selection changes have no effect on keyboard event handling or window close behavior.

## Proposed Solutions

### 1. Recommended: Replace `performClose(nil)` with `close()` (Effort: 5 minutes)

Change both call sites from `performClose(nil)` to `close()`:

**AppDelegate.swift** (line 44):
```swift
// Before:
NSApp.keyWindow?.performClose(nil)
// After:
NSApp.keyWindow?.close()
```

**MkdnCommands.swift** (line 41):
```swift
// Before:
NSApp.keyWindow?.performClose(nil)
// After:
NSApp.keyWindow?.close()
```

**Pros**: Minimal change, directly fixes the issue, `close()` works regardless of style mask
**Cons**: Bypasses `windowShouldClose:` delegate check (but there is no delegate, so this is irrelevant)
**Risk**: Very low -- the window has no unsaved-state guard via `windowShouldClose:` today

### 2. Alternative: Re-add `.closable` after removing `.titled` (Effort: 5 minutes)

In `WindowAccessor.configureWindow`, explicitly re-insert `.closable` after removing `.titled`:

```swift
window.styleMask.remove(.titled)
window.styleMask.insert(.closable)  // Ensure performClose still works
window.styleMask.insert(.resizable)
window.styleMask.insert(.miniaturizable)
```

**Pros**: Preserves `performClose` semantics, enables future `windowShouldClose:` use
**Cons**: May not fully fix the issue -- even with `.closable`, `performClose` behavior on untitled windows may be undefined/macOS-version-dependent
**Risk**: Medium -- relies on AppKit behavior that is not well-documented for untitled windows

### 3. Alternative: Hybrid approach (Effort: 10 minutes)

Use `close()` directly AND keep the local event monitor, but also add `.closable` to the style mask for correctness:

```swift
// WindowAccessor:
window.styleMask.remove(.titled)
window.styleMask.insert(.closable)

// AppDelegate + MkdnCommands:
NSApp.keyWindow?.close()
```

**Pros**: Belt-and-suspenders approach
**Cons**: Slightly redundant
**Risk**: Lowest

## Prevention Measures

1. **Test Cmd+W after any WindowAccessor changes**: Any change to window style masks should be followed by a manual test of Cmd+W, Cmd+M (minimize), and other standard window commands
2. **Add a test harness command for window close**: `mkdn-ctl close` could verify that the window can be closed programmatically
3. **Document the `.titled` removal implications**: Add a comment in `WindowAccessor` noting that removing `.titled` breaks `performClose` and requires `close()` instead

## Evidence Appendix

### E1: Runtime Test - Close Menu Item Fires But Window Doesn't Close
```
$ osascript -e 'tell application "System Events" to count (windows of process "mkdn")'
1
$ osascript -e '...click menu item "Close"...'
$ osascript -e 'tell application "System Events" to count (windows of process "mkdn")'
1
```
Window count remains 1 after clicking Close menu item.

### E2: Window Has Zero Buttons
```
$ osascript -e '...every button of first window...'
0
```
The window has no buttons because `.titled` was removed.

### E3: Git Archaeology - WindowAccessor Before the Break
At commit ad0ae5d (Cmd-W fix), WindowAccessor used:
```swift
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
window.standardWindowButton(.closeButton)?.isHidden = true
```
This kept `.titled` in the style mask, so `performClose` worked.

### E4: Git Archaeology - WindowAccessor After the Break
At commit 3a7e760 (4 days later), WindowAccessor changed to:
```swift
window.styleMask.remove(.titled)
```
This removed `.titled`, breaking `performClose`.

### E5: Standalone Test - performClose vs close() on Untitled Windows
```
performClose failed! Trying close()...
  Window is visible after close(): false
```
`performClose` silently fails on untitled windows; `close()` works correctly.
