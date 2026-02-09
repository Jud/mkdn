# Root Cause Investigation Report - foreground-activation

## Executive Summary
- **Problem**: When launched via `swift run mkdn README.md`, the app window does not come to the foreground; the user must click it manually.
- **Root Cause**: The `NSApp.activate()` call in `applicationDidFinishLaunching` fires before SwiftUI's `WindowGroup` has created and displayed its window. The activation succeeds at the NSApplication level but has no visible effect because there is no window to bring forward yet. No subsequent activation call is made after the window actually appears.
- **Solution**: Move or add an `NSApp.activate()` call to a point after the window is confirmed on-screen (e.g., in `WindowAccessorView.viewDidMoveToWindow()` or via a `DispatchQueue.main.async` delay in `applicationDidFinishLaunching`).
- **Urgency**: Low severity (cosmetic UX), but highly noticeable for CLI workflows. Should be fixed soon.

## Investigation Process
- **Duration**: Single session
- **Hypotheses Tested**:
  1. **Missing activation call entirely** -- REJECTED. `NSApp.activate()` exists in `AppDelegate.applicationDidFinishLaunching`.
  2. **Timing mismatch: activation before window exists** -- CONFIRMED. See root cause analysis.
  3. **LSUIElement / activation policy suppression** -- REJECTED. `setActivationPolicy(.regular)` is called correctly; no `LSUIElement` in Info.plist.
  4. **WindowAccessor suppressing activation** -- REJECTED. `WindowAccessorView` only hides chrome; no focus or ordering interference.
  5. **`swift run` process context preventing activation** -- PARTIALLY CONTRIBUTING. `swift run` launches a child process without a `.app` bundle context, but `setActivationPolicy(.regular)` compensates for this. The primary issue remains timing.
- **Key Evidence**:
  1. `NSApp.activate()` (line 19 of AppDelegate.swift) fires in `applicationDidFinishLaunching`, which occurs before SwiftUI creates the WindowGroup window.
  2. No `makeKeyAndOrderFront`, `orderFrontRegardless`, or subsequent `activate` call exists anywhere in the codebase after window creation.
  3. The `WindowAccessorView.viewDidMoveToWindow()` method (which runs when the window is actually on screen) only configures chrome -- it does not activate the application.

## Root Cause Analysis

### Technical Details

**The activation call is in the right place conceptually but fires at the wrong time relative to window creation.**

The launch sequence is:

```
1. main.swift:42 -- NSApplication.shared.setActivationPolicy(.regular)
   - Creates NSApplication singleton, sets it as a regular (dock-visible) app

2. main.swift:43 -- MkdnApp.main()
   - SwiftUI takes over the run loop

3. AppDelegate.applicationDidFinishLaunching (AppDelegate.swift:18-19)
   - NSApp.activate() is called HERE
   - At this point, SwiftUI's WindowGroup has NOT yet created its NSWindow
   - The activate() call succeeds at the process level but there is no window to bring forward

4. SwiftUI creates the WindowGroup and its initial window
   - DocumentWindow.body is rendered
   - ContentView appears
   - WindowAccessorView.viewDidMoveToWindow() fires -- configures chrome only

5. The window is now visible but behind Terminal/other apps
   - No activation call happens at this point
   - User must click the window manually
```

**File**: `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`, line 19
**Issue**: `NSApp.activate()` is called before the SwiftUI window exists.

**File**: `/Users/jud/Projects/mkdn/mkdn/UI/Components/WindowAccessor.swift`, lines 19-33
**Missed opportunity**: `viewDidMoveToWindow()` is the ideal hook for post-window-creation activation, but it only configures visual chrome.

### Causation Chain

```
NSApp.activate() called in applicationDidFinishLaunching
  --> Activation succeeds at process level (app becomes "active")
  --> But no window exists yet, so nothing visible changes
  --> SwiftUI creates WindowGroup window slightly later (next run-loop cycle)
  --> Window appears behind Terminal because the "activation" already happened
  --> macOS does not re-activate an already-active app
  --> Window stays in background; user must click to bring it forward
```

### Why It Occurred

This is a well-known SwiftUI lifecycle timing issue. In traditional AppKit apps, `applicationDidFinishLaunching` fires after the main window is loaded from a nib/storyboard, so activation there works. In SwiftUI apps (especially those using `WindowGroup`), the window creation is deferred and happens asynchronously after `applicationDidFinishLaunching` returns. The macOS 14+ `NSApp.activate()` (parameterless version) does not force-activate like the old `activate(ignoringOtherApps: true)` did, making the timing even more critical.

### Contributing Factor: `swift run` Process Context

When running via `swift run mkdn`, the binary runs as a child process of the Swift build system without an `.app` bundle wrapper. This means:
- The process starts as a background/accessory process by default
- `setActivationPolicy(.regular)` correctly elevates it, but the activation must happen when a window is ready
- A bundled `.app` launched via `open` or Finder would benefit from Launch Services activation assistance, partially masking this timing bug

## Proposed Solutions

### 1. Recommended: Activate in `WindowAccessorView.viewDidMoveToWindow()` (Low effort, precise)

Add `NSApp.activate()` and `window.makeKeyAndOrderFront(nil)` in `WindowAccessorView.viewDidMoveToWindow()`, which fires at exactly the right time -- when the NSWindow is attached and visible.

```swift
private func configureWindow(_ window: NSWindow) {
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true

    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true

    // Ensure the window comes to the foreground on launch
    window.makeKeyAndOrderFront(nil)
    NSApp.activate()
}
```

**Effort**: ~5 minutes
**Risk**: Low. For multi-window scenarios, this would activate on every new window, which is the expected behavior anyway.
**Pros**: Precise timing, no race conditions, works for both CLI and bundled app launches.
**Cons**: Runs on every window creation, not just initial launch (but this is typically desirable).

### 2. Alternative A: Delayed activation in `applicationDidFinishLaunching` (Low effort, less precise)

```swift
public func applicationDidFinishLaunching(_: Notification) {
    DispatchQueue.main.async {
        NSApp.activate()
    }
}
```

**Effort**: ~2 minutes
**Risk**: Medium. The one-cycle delay may not be enough if SwiftUI takes multiple run-loop cycles to create the window. Fragile across macOS versions.
**Pros**: Minimal code change.
**Cons**: May not reliably work on slower machines or future macOS versions.

### 3. Alternative B: Use `.onAppear` in `DocumentWindow` (Low effort, SwiftUI-idiomatic)

Add `NSApp.activate()` in a `.onAppear` modifier on the `DocumentWindow` body.

**Effort**: ~5 minutes
**Risk**: Low-Medium. `.onAppear` timing in SwiftUI is not guaranteed to correspond exactly to window visibility.
**Pros**: Stays within SwiftUI lifecycle.
**Cons**: `.onAppear` fires when the view is inserted into the hierarchy, which may still precede actual window visibility.

## Prevention Measures

1. When building CLI-launched SwiftUI apps, always test foreground activation from terminal launch, not just from Finder/Xcode.
2. Avoid relying on `applicationDidFinishLaunching` for window-dependent operations in SwiftUI apps -- use `NSViewRepresentable` hooks or `onAppear` instead.
3. Consider adding a UI test that verifies the app window becomes key after CLI launch.

## Evidence Appendix

### Evidence 1: AppDelegate activation call (too early)
**File**: `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift:18-19`
```swift
public func applicationDidFinishLaunching(_: Notification) {
    NSApp.activate()
}
```

### Evidence 2: WindowAccessor does not activate (missed opportunity)
**File**: `/Users/jud/Projects/mkdn/mkdn/UI/Components/WindowAccessor.swift:19-33`
```swift
override public func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let window else { return }
    configureWindow(window)
}

private func configureWindow(_ window: NSWindow) {
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    // No activation or ordering call here
}
```

### Evidence 3: No other activation calls in the codebase
```
$ grep -r "activate\|makeKeyAndOrderFront\|orderFront" mkdn/
mkdn/App/AppDelegate.swift:19:        NSApp.activate()
# (only hit -- no other activation calls anywhere)
```

### Evidence 4: Launch sequence in main.swift
**File**: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift:34-51`
```swift
do {
    let cli = try MkdnCLI.parse()
    if let filePath = cli.file {
        let url = try FileValidator.validate(path: filePath)
        LaunchContext.fileURL = url
    }
    NSApplication.shared.setActivationPolicy(.regular)  // Line 42
    MkdnApp.main()                                       // Line 43 - never returns
}
```

### Evidence 5: macOS API confirms two `activate` variants
```
NSApplication.activate(ignoringOtherApps:) -- deprecated, forces activation
NSApplication.activate()                   -- macOS 14+, respects system policy
```
The codebase uses the new macOS 14+ parameterless `activate()`, which is less aggressive than the deprecated `activate(ignoringOtherApps: true)`. Combined with the timing issue, this means the activation request may be silently ignored or ineffective.
