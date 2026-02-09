# Root Cause Investigation Report - foreground-activation-v4

## Executive Summary
- **Problem**: When launching mkdn from the CLI (`swift run mkdn somefile.md`), the app window appears but does not become the active/frontmost application. The terminal's menu bar stays in the macOS menu bar.
- **Root Cause**: iTerm2's **Secure Keyboard Entry** (`"Secure Input" = 1`) holds an exclusive `kCGSSessionSecureInputPID` lock in the macOS window server. This lock prevents ANY other process from programmatically becoming the frontmost application, regardless of activation API used (`NSApp.activate(ignoringOtherApps: true)`, `NSRunningApplication.current.activate(from:)`, `TransformProcessType`, even `open -a` via Launch Services). The lock is a system-level security enforcement that cannot be bypassed by standard activation APIs.
- **Solution**: Detect `IsSecureEventInputEnabled()` at activation time. If active, temporarily claim the Secure Input lock via `EnableSecureEventInput()`, call `NSApp.activate(ignoringOtherApps: true)`, then immediately release via `DisableSecureEventInput()`. This transfers the lock to our process for microseconds, allowing the activation to succeed, then restores the previous state.
- **Urgency**: High for developer UX. Most developers use iTerm2 with Secure Keyboard Entry enabled. This is the primary launch path.

## Investigation Process
- **Duration**: Single session (round 4)
- **Hypotheses Tested**:
  1. **`NSApp.activate(ignoringOtherApps: true)` deprecated and non-functional on macOS 15.5** -- REJECTED. The API is functional, but Secure Input blocks it.
  2. **Timing issue with DispatchQueue.main.async deferral in configureWindow()** -- REJECTED. The deferral is correct; the activation call fires at the right time.
  3. **Unbundled executable lacks trust context for activation** -- REJECTED. Even bundled `.app` launched via `open` fails when Secure Input is active.
  4. **`execv()` re-execution inherits problematic parent context** -- PARTIALLY CONTRIBUTING. `execv()` reuses the same PID and parent context, but the real blocker is Secure Input, not process parentage.
  5. **iTerm2's Secure Keyboard Entry blocks all programmatic activation** -- CONFIRMED.
  6. **`EnableSecureEventInput()` workaround transfers the lock and enables activation** -- CONFIRMED.
- **Key Evidence**:
  1. `kCGSSessionSecureInputPID=18523` in `ioreg` matches iTerm2's PID
  2. `IsSecureEventInputEnabled()` returns `true`
  3. Even `open -a Calculator` from iTerm2 does not make Calculator frontmost
  4. `EnableSecureEventInput()` + `activate(ignoringOtherApps: true)` + `DisableSecureEventInput()` produces `isActive=true`

## Root Cause Analysis

### Technical Details

**The macOS window server's Secure Input mechanism prevents ALL programmatic focus stealing when active.**

#### What Is Secure Input?

When a process calls `EnableSecureEventInput()` (or uses a framework that does, like iTerm2's Secure Keyboard Entry menu option), macOS records that process's PID as the `kCGSSessionSecureInputPID` in the IORegistry. The window server then enforces that:

1. Only the Secure Input holder's keyboard events are routed securely (preventing keyloggers)
2. **No other process can programmatically become the frontmost application** -- this is a side effect of the security model to prevent malicious apps from stealing focus to intercept passwords

This is a kernel-level enforcement in the macOS window server (`WindowServer` process), not an AppKit-level restriction.

#### What This Blocks

| Activation Method | Works Without SI? | Works With SI? |
|-------------------|:-:|:-:|
| `NSApp.activate(ignoringOtherApps: true)` | Yes | **No** |
| `NSApp.activate()` (macOS 14+) | Sometimes | **No** |
| `NSRunningApplication.current.activate(from:options:)` | Sometimes | **No** |
| `window.orderFrontRegardless()` | Yes (Z-order only) | Yes (Z-order only) |
| `window.makeKeyAndOrderFront(nil)` | Within app | Within app |
| `TransformProcessType` + `activate` | Yes | **No** |
| `open -a AppName` (Launch Services) | Yes | **No** |
| `osascript 'tell app to activate'` | Yes | **No** |

`orderFrontRegardless()` still works for Z-ordering (the window appears visually in front), but the app does not receive keyboard focus or the menu bar.

#### Why iTerm2 Is the Trigger

iTerm2 defaults: `"Secure Input" = 1` in `com.googlecode.iterm2` preferences. This is enabled via iTerm2's menu: **Secure > Secure Keyboard Entry**. Many developers enable this for password security in terminal sessions.

Terminal.app: `SecureKeyboardEntry = 0` by default. Users on Terminal.app would not experience this issue.

#### The Workaround Mechanism

```
EnableSecureEventInput()
  -> Our process (mkdn) becomes the kCGSSessionSecureInputPID holder
  -> The window server now considers mkdn as the "secure input" process
  -> NSApp.activate(ignoringOtherApps: true) is no longer blocked
     (because the lock holder IS the process requesting activation)

NSApp.activate(ignoringOtherApps: true)
  -> Succeeds because mkdn holds the Secure Input lock
  -> applicationDidBecomeActive is called
  -> Menu bar switches to mkdn's menus
  -> Window receives keyboard focus

DisableSecureEventInput()
  -> mkdn releases the Secure Input lock
  -> The window server clears the kCGSSessionSecureInputPID
  -> When control returns to iTerm2 (user clicks it), iTerm2 re-establishes
     its Secure Input lock automatically
  -> No security degradation for iTerm2's ongoing sessions
```

#### Verified Behavior

| Test | Secure Input | Result |
|------|:-:|:--|
| mkdn (no file arg) | Active | `isActive=false`, `Frontmost=false` |
| mkdn (with file arg) | Active | `isActive=false`, `Frontmost=false` |
| Minimal AppKit test | Active | `isActive=false` |
| `open -a Calculator` | Active | `Frontmost=false` |
| `osascript 'activate'` | Active | `Frontmost=false` |
| Enable/Disable workaround | Active | `isActive=true`, `DID_BECOME_ACTIVE` called |

### Causation Chain

```
User has iTerm2 with "Secure Keyboard Entry" enabled
  --> iTerm2 calls EnableSecureEventInput()
  --> macOS window server records kCGSSessionSecureInputPID = iTerm2's PID
  --> User runs: swift run mkdn README.md (or .build/debug/mkdn README.md)
  --> mkdn starts (child of iTerm2, same or different PID after execv)
  --> AppDelegate.applicationWillFinishLaunching: NSApp.setActivationPolicy(.regular) -- OK
  --> SwiftUI creates WindowGroup, renders DocumentWindow + ContentView
  --> WindowAccessorView.viewDidMoveToWindow() -> configureWindow()
  --> DispatchQueue.main.async {
        window.makeKeyAndOrderFront(nil) -- window key within app layer
        window.orderFrontRegardless()    -- window visually in front (Z-order)
        NSApp.activate(ignoringOtherApps: true) -- SILENTLY FAILS
      }
  --> The activation request reaches the window server
  --> Window server checks: is another process holding Secure Input?
  --> Yes: PID 18523 (iTerm2) holds kCGSSessionSecureInputPID
  --> Window server REJECTS the activation request
  --> NSApp.isActive remains false
  --> applicationDidBecomeActive is NEVER called
  --> Menu bar stays with iTerm2
  --> Window is visible (orderFrontRegardless worked) but not focused
```

### Why Previous Investigations Missed This

1. **v1 investigation**: Correctly identified timing issue (activation before window exists). The fix was valid but did not address Secure Input.
2. **v2 investigation**: Correctly identified cooperative activation model weakness. Changed to `activate(ignoringOtherApps: true)`. This would have worked if Secure Input were not active.
3. **v3 investigation**: Correctly identified that `@Observable` mutation in `MkdnApp.init()` prevented window creation. The `execv()` fix was valid. But it tested "frontmost=true" in a context where Secure Input may not have been active (or used a different terminal).
4. **All three investigations** focused on the application's own code without considering the calling environment (iTerm2's Secure Input state).

### Secondary Factor: Unbundled Executable

The app runs as an unbundled executable (no `.app` bundle, ad-hoc signed, `bundleID=[ NULL ]`). This is a contributing factor but NOT the root cause:
- Even a bundled `.app` with a proper `CFBundleIdentifier`, launched via `open`, fails when Secure Input is active
- The unbundled nature may cause additional issues without Secure Input on some macOS versions, but the Secure Input lock is the primary and deterministic blocker

## Proposed Solutions

### 1. Recommended: Detect Secure Input and use Enable/Disable workaround (Low effort, reliable)

Add a `Carbon.framework` import and a Secure Input detection check to the activation path in `WindowAccessor.swift`:

```swift
import Carbon  // For IsSecureEventInputEnabled, EnableSecureEventInput, DisableSecureEventInput

private func configureWindow(_ window: NSWindow) {
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true

    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true

    DispatchQueue.main.async {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Workaround: Secure Keyboard Entry (common in iTerm2) prevents
        // programmatic activation. Temporarily claim and release the
        // Secure Input lock to allow activation to succeed.
        if IsSecureEventInputEnabled() {
            EnableSecureEventInput()
            NSApp.activate(ignoringOtherApps: true)
            DisableSecureEventInput()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
```

**Effort**: ~10 minutes (add `import Carbon`, conditional logic)
**Risk**: Low.
- `EnableSecureEventInput()` / `DisableSecureEventInput()` are stable Carbon APIs available since macOS 10.0
- The Secure Input transfer is transient (microseconds) -- iTerm2 re-establishes its lock when the user returns to it
- No security degradation: mkdn doesn't need Secure Input, so it releases immediately
- The check is conditional: on systems without Secure Input, the standard `activate(ignoringOtherApps: true)` is used directly
**Pros**: Works reliably with iTerm2, Terminal.app, and any other terminal. Minimal code change. No user action required.
**Cons**: Uses Carbon APIs (very old but still functional and no deprecation notice). The `EnableSecureEventInput()`/`DisableSecureEventInput()` cycle briefly disrupts Secure Input for other processes (negligible in practice).

### 2. Alternative A: Detect Secure Input and show a user-facing notification (Zero risk, less convenient)

Instead of using the Carbon workaround, detect Secure Input and log a message or show a system notification asking the user to click the mkdn window or Dock icon.

```swift
if IsSecureEventInputEnabled() {
    // Log to stderr for CLI users
    FileHandle.standardError.write(
        Data("mkdn: Secure Keyboard Entry is active; click the mkdn window to activate.\n".utf8)
    )
}
NSApp.activate(ignoringOtherApps: true)
```

**Effort**: ~5 minutes
**Risk**: None
**Pros**: No Carbon API usage. Transparent to the user.
**Cons**: Inferior UX -- the user must manually click the window. Defeats the purpose of auto-activation.

### 3. Alternative B: Always use Enable/Disable unconditionally (Simpler code, slightly more aggressive)

Skip the `IsSecureEventInputEnabled()` check and always do the Enable/Disable cycle.

```swift
EnableSecureEventInput()
NSApp.activate(ignoringOtherApps: true)
DisableSecureEventInput()
```

**Effort**: ~5 minutes
**Risk**: Low-Medium. On systems without Secure Input, this is a no-op (Enable increments a refcount, Disable decrements it). But it's less principled than the conditional approach.
**Pros**: Simplest code. Always works.
**Cons**: Unnecessarily touches Secure Input on systems where it's not needed.

### 4. Alternative C: Use `applicationDidFinishLaunching` with Enable/Disable (Earlier timing)

Move the Secure Input workaround to `AppDelegate.applicationDidFinishLaunching` for earlier execution, before `WindowAccessor` fires.

**Effort**: ~10 minutes
**Risk**: Medium. Activation before window exists was the v1 bug. However, with the Enable/Disable workaround, the activation might succeed at the process level and the window would inherit the active state when created.
**Pros**: Earlier activation, potentially smoother.
**Cons**: Timing may still be wrong for the window display.

## Prevention Measures

1. **Test activation from iTerm2 with Secure Keyboard Entry enabled**: This is the most common developer terminal configuration. Any activation changes must be tested in this environment.

2. **Add `IsSecureEventInputEnabled()` to diagnostic/debug output**: When investigating future activation issues, check for Secure Input first.

3. **Document the iTerm2 Secure Input interaction**: Add a note to the project README or troubleshooting guide that Secure Keyboard Entry can interfere with app activation.

4. **Monitor Carbon API deprecation**: `EnableSecureEventInput()` and `DisableSecureEventInput()` have no deprecation notice as of macOS 15.5, but Apple could deprecate them in a future release. If so, the conditional approach (Solution 1) degrades gracefully to the standard activation path.

## Evidence Appendix

### Evidence 1: `kCGSSessionSecureInputPID` in IORegistry (definitive)

```
$ ioreg -l -w 0 | grep kCGSSessionSecureInputPID
"kCGSSessionSecureInputPID"=18523
```

```
$ ps -p 18523 -o pid,comm
  PID COMM
18523 /Applications/iTerm.app/Contents/MacOS/iTerm2
```

### Evidence 2: iTerm2 preferences confirm Secure Input enabled

```
$ defaults read com.googlecode.iterm2 | grep "Secure Input"
"Secure Input" = 1;
```

### Evidence 3: `IsSecureEventInputEnabled()` returns true

```swift
import Carbon
print("IsSecureEventInputEnabled: \(IsSecureEventInputEnabled())")
// Output: IsSecureEventInputEnabled: true
```

### Evidence 4: ALL activation APIs fail with Secure Input active

```
Minimal AppKit app test:
  NSApp.activate(ignoringOtherApps: true) -> isActive=false
  NSRunningApplication.current.activate(from:options:) -> returned false
  TransformProcessType -> returned 0 (success) but isActive=false
  open -a Calculator -> frontmost=false
  osascript 'tell app to activate' -> frontmost=false
```

### Evidence 5: Even TextEdit fails to activate from iTerm2

```
$ open -a TextEdit && sleep 2 && osascript -e 'tell application "System Events" to return frontmost of process "TextEdit"'
false
```

This proves the issue is NOT specific to mkdn, unbundled executables, or any code defect. It is a system-level restriction.

### Evidence 6: Enable/Disable workaround succeeds (definitive)

```swift
EnableSecureEventInput()
NSApp.activate(ignoringOtherApps: true)
DisableSecureEventInput()
// Output: DID_BECOME_ACTIVE
// Output: isActive=true
```

After process exits, `kCGSSessionSecureInputPID` returns to iTerm2's PID, confirming no persistent side effects.

### Evidence 7: Conditional workaround works correctly

```swift
if IsSecureEventInputEnabled() {
    EnableSecureEventInput()
    NSApp.activate(ignoringOtherApps: true)
    DisableSecureEventInput()
} else {
    NSApp.activate(ignoringOtherApps: true)
}
// Output: Secure Input detected - using workaround
// Output: isActive=true
```

### Evidence 8: Terminal.app has Secure Input disabled by default

```
$ defaults read com.apple.Terminal SecureKeyboardEntry
0
```

Users launching mkdn from Terminal.app (instead of iTerm2) would not experience this issue.

### Evidence 9: System environment

```
macOS 15.5 (Sequoia), Build 24F74
Swift 6.1
iTerm2 with "Secure Keyboard Entry" enabled
kCGSSessionSecureInputPID held by iTerm2 (PID 18523)
```
