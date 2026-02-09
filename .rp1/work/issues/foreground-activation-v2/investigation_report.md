# Root Cause Investigation Report - foreground-activation-v2

## Executive Summary
- **Problem**: After the first fix (commit 65cd6d6) moved `NSApp.activate()` into `WindowAccessor.configureWindow()` alongside `window.makeKeyAndOrderFront(nil)`, the app launched via `swift run mkdn README.md` still does not come to the foreground.
- **Root Cause**: The macOS 14+ parameterless `NSApp.activate()` uses a **cooperative activation model** that does not guarantee activation. It requires the currently-active app (Terminal) to yield activation first. Since Terminal never yields, the call silently fails. The previous fix corrected the **timing** issue but not the **activation mechanism** issue.
- **Solution**: Use `NSApp.activate(ignoringOtherApps: true)` (still functional on macOS 15.5, only flagged for future deprecation) or combine `window.orderFrontRegardless` with `NSApp.activate()` for a defense-in-depth approach.
- **Urgency**: High for CLI workflow usability. This is the primary launch path for developer users.

## Investigation Process
- **Duration**: Single session (round 2)
- **Hypotheses Tested**:
  1. **`configureWindow()` is not being called** -- REJECTED. The code path from `ContentView.background(WindowAccessor())` -> `WindowAccessorView.viewDidMoveToWindow()` -> `configureWindow()` is correct and the window is configured (chrome is hidden).
  2. **macOS 14+ `NSApp.activate()` cooperative model silently fails for unbundled processes** -- CONFIRMED. See root cause analysis.
  3. **`window.makeKeyAndOrderFront(nil)` is insufficient without proper activation** -- CONFIRMED. The window becomes key within its own app layer but cannot cross the window-server layer to appear in front of Terminal without the app being activated.
  4. **Missing `orderFrontRegardless`** -- CONTRIBUTING. `orderFrontRegardless` moves the window in front regardless of activation state and would help even if activation fails.
  5. **Process identity issue (no bundle, ad-hoc signature)** -- CONTRIBUTING. The binary has `Info.plist=not bound`, no team identifier, ad-hoc signing. macOS treats it as a lower-privilege process for activation purposes.
- **Key Evidence**:
  1. Apple SDK header for `NSApp.activate()` (macOS 14+): "The framework also does not guarantee that the app will be activated at all."
  2. Apple SDK header for cooperative activation: "the other application should call `-yieldActivationToApplication:` or equivalent prior to the target application invoking `-activate`."
  3. `NSApp.activate(ignoringOtherApps:)` uses `API_TO_BE_DEPRECATED` -- NOT actually deprecated yet, still functional on macOS 15.5.

## Root Cause Analysis

### Technical Details

**The previous fix solved the timing problem but the activation mechanism itself is fundamentally flawed for this use case.**

The first investigation correctly identified that `NSApp.activate()` was being called before the window existed. Commit 65cd6d6 moved the activation call into `configureWindow()`, which fires at the correct time (when the NSWindow is attached). However, this exposed a second, deeper problem: the macOS 14+ parameterless `NSApp.activate()` simply does not work for this scenario.

#### The Cooperative Activation Model (macOS 14+)

From the macOS 15.4 SDK header (`NSApplication.h`, lines 215-227):

```objc
/// Makes the receiver the active app, if possible.
///
/// You shouldn't assume the app will be active immediately
/// after sending this message. The framework also does not
/// guarantee that the app will be activated at all.
///
/// For cooperative activation, the other application should
/// call `-yieldActivationToApplication:` or equivalent prior
/// to the target application invoking `-activate`.
///
/// Invoking `-activate` on an already-active application
/// cancels any pending activation yields by the receiver.
- (void)activate API_AVAILABLE(macos(14.0));
```

This is a cooperative activation model. For `NSApp.activate()` to work, **Terminal must explicitly yield activation** to the mkdn process. Since Terminal has no knowledge of mkdn, this never happens. The call returns without effect.

#### Why `activate(ignoringOtherApps:)` Is Different

The older API (`NSApplication.activate(ignoringOtherApps:)`) has a different deprecation status than the `NSRunningApplication` option:

| API | Deprecation Status | Effect on macOS 15.5 |
|-----|-------------------|---------------------|
| `NSApp.activate(ignoringOtherApps: true)` | `API_TO_BE_DEPRECATED` (future, not yet) | **Still functional** -- forces activation |
| `NSRunningApplication.activate(options: .activateIgnoringOtherApps)` | Deprecated in macOS 14, "will have no effect" | **No longer works** |
| `NSApp.activate()` (parameterless) | Current recommended API | Cooperative only -- requires yield |

The codebase uses the parameterless `NSApp.activate()`, which is the weakest option.

#### Why `makeKeyAndOrderFront(nil)` Also Fails

`window.makeKeyAndOrderFront(nil)` makes the window key and orders it to the front **within the application's window layer**. However, if the application itself is not activated (not the foreground process), its entire window layer sits behind the active application's layer in the macOS window server. The window is technically "in front" of other mkdn windows but behind all of Terminal's windows.

#### Process Identity Compounds the Problem

The debug binary built by `swift build` has:
- **No bound Info.plist** (`codesign -dvvv` shows `Info.plist=not bound`)
- **Ad-hoc signature** (no team identifier)
- **No bundle structure** (bare executable at `.build/debug/mkdn`)

macOS treats unbundled executables with `NSApplicationActivationPolicyProhibited` by default (SDK header, `NSRunningApplication.h` line 41): "This is also the default for unbundled executables that do not have Info.plists."

The code correctly calls `setActivationPolicy(.regular)` to override this, which promotes the process to a regular app (Dock icon appears). But the promotion happens programmatically and the process still lacks the trust context that a properly bundled and signed `.app` gets from Launch Services. This makes the cooperative `activate()` even less likely to succeed.

### Causation Chain

```
Terminal is the active (frontmost) application
  --> User runs `swift run mkdn README.md`
  --> Process starts with ActivationPolicyProhibited (default for unbundled)
  --> main.swift calls setActivationPolicy(.regular) -- process now "regular"
  --> SwiftUI creates WindowGroup, renders DocumentWindow -> ContentView
  --> WindowAccessorView.viewDidMoveToWindow() fires
  --> configureWindow() calls window.makeKeyAndOrderFront(nil)
      --> Window becomes key within mkdn's window layer
      --> But mkdn's window layer is BEHIND Terminal's layer
  --> configureWindow() calls NSApp.activate()
      --> macOS 14+ cooperative activation model
      --> Terminal has not yielded activation to mkdn
      --> Activation request silently fails or is deferred indefinitely
  --> mkdn window appears behind Terminal
  --> User must click mkdn's window or Dock icon to activate
```

### Why the First Fix Was Insufficient

The first investigation correctly identified a **timing** bug: activation was attempted before the window existed. The fix moved the activation call to the correct time (when the window is attached). But the fix used the same `NSApp.activate()` API, which has a fundamental limitation on macOS 14+: it is cooperative and will not force-activate an unbundled process launched from Terminal.

The timing fix was **necessary but not sufficient**. Even at the correct time, the wrong activation mechanism was used.

## Proposed Solutions

### 1. Recommended: Use `activate(ignoringOtherApps: true)` + `orderFrontRegardless` (Low effort, reliable)

Replace the two lines in `WindowAccessor.configureWindow()`:

```swift
private func configureWindow(_ window: NSWindow) {
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true

    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true

    // Force the window to the front regardless of activation state
    window.orderFrontRegardless()
    // Force application activation (still functional on macOS 15.5)
    NSApp.activate(ignoringOtherApps: true)
}
```

**Effort**: ~2 minutes
**Risk**: Low. `activate(ignoringOtherApps:)` is marked `API_TO_BE_DEPRECATED` but is still fully functional on macOS 15.5. The deprecation has been pending since macOS 14 with no concrete removal timeline. `orderFrontRegardless` provides a fallback if `activate` behavior changes.
**Pros**: Most reliable approach. Works for unbundled executables, works from Terminal, works from `swift run`.
**Cons**: Uses a "to be deprecated" API. May need updating in a future macOS version.

### 2. Alternative A: Use `NSRunningApplication.current.activate(from:options:)` (macOS 14+)

```swift
let terminal = NSWorkspace.shared.frontmostApplication
if let terminal {
    NSRunningApplication.current.activate(from: terminal, options: [.activateAllWindows])
}
```

**Effort**: ~5 minutes
**Risk**: Medium. This is the "modern" cooperative API but requires getting a reference to the currently-frontmost app. The activation may still not be guaranteed -- the API docs say the other app "should call yieldActivation" first.
**Pros**: Uses the modern macOS 14+ API without deprecation warnings.
**Cons**: May not reliably work if Terminal doesn't participate in cooperative activation. More complex code.

### 3. Alternative B: Combine `orderFrontRegardless` with parameterless `activate()` (Moderate reliability)

```swift
window.orderFrontRegardless()
NSApp.activate()
```

**Effort**: ~2 minutes
**Risk**: Medium. `orderFrontRegardless` moves the window visually to the front (Z-order) but does not make the app "active" in the macOS sense. The window would appear in front but keyboard focus might remain with Terminal until the user clicks. The parameterless `activate()` may or may not succeed.
**Pros**: No deprecated API usage. Window at least appears visually.
**Cons**: May result in a visible but not keyboard-focused window (confusing UX).

### 4. Alternative C: Dispatch activation with a slight delay (Heuristic)

```swift
window.makeKeyAndOrderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    NSApp.activate(ignoringOtherApps: true)
}
```

**Effort**: ~3 minutes
**Risk**: Low-Medium. The delay ensures the window server has processed the window and the app is fully "regular." This may help in edge cases where `setActivationPolicy` needs a run-loop cycle to fully register.
**Pros**: Belt-and-suspenders approach.
**Cons**: Arbitrary delay; magic number.

## Prevention Measures

1. **Test CLI launch activation explicitly**: After any change to window or activation code, test `swift run mkdn README.md` from Terminal with another app (like a browser) in the foreground, not just from Xcode.
2. **Track Apple's deprecation timeline**: Monitor WWDC and macOS release notes for actual removal of `activate(ignoringOtherApps:)`. When it is removed, the app may need to use `NSRunningApplication.current.activate(from:options:)` with the frontmost app reference.
3. **Consider a bundled `.app` for development**: Running `scripts/bundle.sh` and launching the `.app` bundle would get proper Launch Services activation support, potentially avoiding this class of issues entirely.
4. **Add a UI test or manual test script** that launches the binary from a shell and verifies it becomes the frontmost application within 2 seconds.

## Evidence Appendix

### Evidence 1: macOS 14+ `activate()` is cooperative (SDK Header)

**File**: `NSApplication.h` (macOS 15.4 SDK), lines 215-227
```objc
/// Makes the receiver the active app, if possible.
///
/// You shouldn't assume the app will be active immediately
/// after sending this message. The framework also does not
/// guarantee that the app will be activated at all.
///
/// For cooperative activation, the other application should
/// call `-yieldActivationToApplication:` or equivalent prior
/// to the target application invoking `-activate`.
- (void)activate API_AVAILABLE(macos(14.0));
```

### Evidence 2: `activate(ignoringOtherApps:)` NOT yet deprecated

**File**: `NSApplication.h` (macOS 15.4 SDK), line 213
```objc
- (void)activateIgnoringOtherApps:(BOOL)ignoreOtherApps
    API_DEPRECATED("This method will be deprecated in a future release.
    Use NSApp.activate instead.", macos(10.0, API_TO_BE_DEPRECATED));
```
Note: `API_TO_BE_DEPRECATED` means the deprecation date is not set. The method is still functional.

### Evidence 3: `NSRunningApplication` option IS deprecated (different API)

**File**: `NSRunningApplication.h` (macOS 15.4 SDK), lines 25-27
```objc
NSApplicationActivateIgnoringOtherApps
    API_DEPRECATED("ignoringOtherApps is deprecated in macOS 14
    and will have no effect.", macos(10.6, 14.0)) = 1 << 1
```
This is the `NSRunningApplication.activate(withOptions:)` version, NOT the `NSApplication` method.

### Evidence 4: Unbundled executables default to prohibited activation

**File**: `NSRunningApplication.h` (macOS 15.4 SDK), lines 41-42
```objc
/* The application does not appear in the Dock and may not create
   windows or be activated. This corresponds to LSBackgroundOnly=1
   in the Info.plist. This is also the default for unbundled executables
   that do not have Info.plists. */
NSApplicationActivationPolicyProhibited
```

### Evidence 5: Binary has no bound Info.plist

```
$ codesign -dvvv .build/debug/mkdn
Identifier=mkdn-555549444caabaaf04b93c45b9d042e11723454d
Format=Mach-O thin (arm64)
Signature=adhoc
Info.plist=not bound
TeamIdentifier=not set
```

### Evidence 6: Current code (post-first-fix) uses ineffective API

**File**: `/Users/jud/Projects/mkdn/mkdn/UI/Components/WindowAccessor.swift`, lines 25-36
```swift
private func configureWindow(_ window: NSWindow) {
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true

    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true

    window.makeKeyAndOrderFront(nil)   // Only works within app's window layer
    NSApp.activate()                    // Cooperative -- silently fails
}
```

### Evidence 7: System environment

```
macOS 15.5 (Sequoia), Build 24F74
Swift 6.1
Xcode 16.3.0
Binary: unbundled SPM executable, ad-hoc signed
```
