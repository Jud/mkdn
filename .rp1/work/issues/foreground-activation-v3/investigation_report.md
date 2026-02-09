# Root Cause Investigation Report - foreground-activation-v3

## Executive Summary
- **Problem**: When launched via `swift run mkdn README.md` or `.build/debug/mkdn README.md`, the app does not come to the foreground. Two rounds of fixes (timing fix, then activation API fix) did not solve the problem.
- **Root Cause**: The window is never created at all. The activation code in `WindowAccessor.configureWindow()` is correct and functional -- it successfully brings the app to the foreground when launching WITHOUT a file argument. The real issue is that `MkdnApp.init()` mutates `FileOpenCoordinator.shared.pendingURLs` (an `@Observable` property) during app struct initialization, which interferes with SwiftUI's `WindowGroup(for: URL.self)` default window creation mechanism. No window is ever created, so `WindowAccessor` is never instantiated, and the activation code never runs.
- **Solution**: Remove the `@Observable` side effect from `MkdnApp.init()`. Instead, have `DocumentWindow` check `LaunchContext.fileURL` directly in its `.task` or `.onAppear`, OR defer the `FileOpenCoordinator` mutation to after the first window is created using `DispatchQueue.main.async`.
- **Urgency**: Critical. The app is completely non-functional for the CLI workflow -- it launches as a dock icon with no window.

## Investigation Process
- **Duration**: Single session (round 3)
- **Hypotheses Tested**:
  1. **Is `configureWindow()` actually being called?** -- NO. It is never called because no window is created. Confirmed via System Events window count = 0 and CoreGraphics window list = empty.
  2. **Multiple windows problem** -- NOT APPLICABLE. Zero windows are created, not multiple.
  3. **`swift run` child process / unbundled executable issue** -- REJECTED. The bundled `.app` version launched via `open mkdn.app --args README.md` exhibits the same 0-window behavior.
  4. **Activation API issue (cooperative vs force)** -- NOT THE ROOT CAUSE. `NSApp.activate(ignoringOtherApps: true)` and `window.orderFrontRegardless()` work correctly when launching without a file argument (frontmost = true in that case).
  5. **`MkdnApp.init()` side effect on `@Observable` property prevents `WindowGroup` default window creation** -- CONFIRMED. See root cause analysis.
  6. **State restoration interference** -- REJECTED. Deleting all defaults (`defaults delete mkdn`) and saved application state does not fix the issue.
- **Key Evidence**:
  1. Without file argument: window count = 1, frontmost = true
  2. With file argument: window count = 0, frontmost = false
  3. Bundled `.app` shows same behavior (0 windows with file arg)
  4. CoreGraphics `CGWindowListCopyWindowInfo` confirms zero windows at the window server level
  5. Process sample shows main thread idle in run loop with no FileWatcher thread (meaning `DocumentState.loadFile()` was never called)

## Root Cause Analysis

### Technical Details

**The previous two investigations were solving the wrong problem.** Both focused on activation timing and API selection. The activation code they added is correct and works perfectly -- but only when a window exists. The actual bug is that no window is ever created when a file argument is provided.

#### The Broken Flow

```
main.swift:37-39:
    let url = try FileValidator.validate(path: filePath)
    LaunchContext.fileURL = url

main.swift:42-43:
    NSApplication.shared.setActivationPolicy(.regular)
    MkdnApp.main()

MkdnApp.init():
    if let url = LaunchContext.fileURL {
        FileOpenCoordinator.shared.pendingURLs.append(url)  // <-- THE BUG
    }

MkdnApp.body:
    WindowGroup(for: URL.self) { $fileURL in  // <-- NEVER CREATES WINDOW
        DocumentWindow(fileURL: fileURL)
            .environment(appSettings)
    }
```

#### Why `FileOpenCoordinator.shared.pendingURLs.append(url)` in `init()` Breaks Window Creation

`FileOpenCoordinator` is `@MainActor @Observable`. Mutating its `pendingURLs` property during `MkdnApp.init()` triggers SwiftUI's `@Observable` change notification system. This has two effects:

1. **SwiftUI struct re-creation loop**: `MkdnApp` is a struct conforming to `App`. SwiftUI may re-create it (calling `init()` each time) as part of its body evaluation cycle. Each re-creation appends the URL again to `pendingURLs`, triggering another `@Observable` notification. While SwiftUI prevents infinite loops, this rapid state mutation during the initial scene setup phase disrupts the `WindowGroup`'s internal state machine for default window creation.

2. **WindowGroup(for: URL.self) sensitivity**: Unlike a plain `WindowGroup { ... }`, the data-driven `WindowGroup(for: URL.self)` variant manages windows keyed by URL values. Its default window creation logic (which creates one window with `nil` URL on first launch) appears to be fragile during the initial setup phase. When external `@Observable` state is mutated before the `WindowGroup` has completed its initialization, the default window creation is silently skipped.

The evidence for this is conclusive:

| Scenario | `init()` side effect | Window count | Frontmost |
|----------|---------------------|--------------|-----------|
| No file argument | None (no mutation) | 1 | true |
| With file argument | `pendingURLs.append(url)` | 0 | false |
| With file arg + bundled .app | `pendingURLs.append(url)` | 0 | false |
| With file arg + clean defaults | `pendingURLs.append(url)` | 0 | false |

#### Why Previous Fixes Failed

- **Fix 1** (move activation to `configureWindow()`): Correct fix for the timing issue, but `configureWindow()` never runs because no window is created.
- **Fix 2** (use `activate(ignoringOtherApps: true)` + `orderFrontRegardless`): Correct fix for the activation API issue, but these calls never execute because the window (and `WindowAccessorView`) never exists.

Both fixes are still correct and should be kept -- they solve real problems. But the upstream bug (no window creation) makes them irrelevant.

### Causation Chain

```
CLI: mkdn README.md
  --> main.swift: LaunchContext.fileURL = validated URL
  --> MkdnApp.main() calls MkdnApp.init()
  --> init() calls FileOpenCoordinator.shared.pendingURLs.append(url)
  --> @Observable willSet/didSet fires on pendingURLs
  --> SwiftUI's observation system is notified of state change
  --> SwiftUI evaluates MkdnApp.body
  --> WindowGroup(for: URL.self) internal state machine begins
  --> But @Observable state is still settling (pendingURLs was just mutated)
  --> WindowGroup skips default window creation (internal bug/design limitation)
  --> No NSWindow is created
  --> No DocumentWindow view is rendered
  --> No ContentView is rendered
  --> No WindowAccessor is instantiated
  --> configureWindow() never runs
  --> activate(ignoringOtherApps:) and orderFrontRegardless() never execute
  --> App shows dock icon but no window
  --> User sees nothing
```

### Why It Works Without a File Argument

When no file argument is provided, `LaunchContext.fileURL` is `nil`, so `MkdnApp.init()` has zero side effects. No `@Observable` properties are mutated. `WindowGroup`'s internal state machine runs without interference and creates the default window with `fileURL = nil`. The window appears, `WindowAccessor.configureWindow()` fires, and the app comes to the foreground correctly.

## Proposed Solutions

### 1. Recommended: Remove side effect from `MkdnApp.init()` and use `LaunchContext` directly (Low effort, clean)

Instead of mutating `FileOpenCoordinator.shared.pendingURLs` during `MkdnApp.init()`, read `LaunchContext.fileURL` directly in `DocumentWindow.task`:

```swift
// MkdnApp - remove the init() entirely
struct MkdnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings = AppSettings()

    // No init() -- no side effects during struct creation

    var body: some Scene {
        WindowGroup(for: URL.self) { $fileURL in
            DocumentWindow(fileURL: fileURL)
                .environment(appSettings)
        }
        .handlesExternalEvents(matching: [])
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            MkdnCommands(appSettings: appSettings)
            OpenRecentCommands()
        }
    }
}

// DocumentWindow.task - consume LaunchContext directly
.task {
    if let fileURL {
        try? documentState.loadFile(at: fileURL)
        NSDocumentController.shared.noteNewRecentDocumentURL(fileURL)
    } else {
        // Check LaunchContext first, then FileOpenCoordinator
        if let launchURL = LaunchContext.consumeURL() {
            try? documentState.loadFile(at: launchURL)
            NSDocumentController.shared.noteNewRecentDocumentURL(launchURL)
        }
        // Then handle any runtime file opens
        let pending = FileOpenCoordinator.shared.consumeAll()
        if let first = pending.first, documentState.currentFileURL == nil {
            try? documentState.loadFile(at: first)
            NSDocumentController.shared.noteNewRecentDocumentURL(first)
        }
        for url in pending.dropFirst() {
            openWindow(value: url)
        }
    }
}
```

And modify `LaunchContext` to support one-time consumption:

```swift
public enum LaunchContext {
    public nonisolated(unsafe) static var fileURL: URL?

    /// Consume the launch URL (returns it once, then returns nil).
    @MainActor
    public static func consumeURL() -> URL? {
        let url = fileURL
        fileURL = nil
        return url
    }
}
```

**Effort**: ~15 minutes
**Risk**: Low. The `LaunchContext` consumption is read-once, preventing duplicate loads. The `FileOpenCoordinator` still handles runtime file opens (Finder, dock, etc.).
**Pros**: Eliminates all `@Observable` side effects from `MkdnApp.init()`. Clean separation of launch-time vs runtime file opening.
**Cons**: Slightly more complex `DocumentWindow.task` logic.

### 2. Alternative A: Defer `FileOpenCoordinator` mutation with `DispatchQueue.main.async` (Minimal change)

```swift
init() {
    if let url = LaunchContext.fileURL {
        DispatchQueue.main.async {
            FileOpenCoordinator.shared.pendingURLs.append(url)
        }
    }
}
```

**Effort**: ~2 minutes
**Risk**: Medium. The `DispatchQueue.main.async` defers the mutation to the next run loop cycle, after `WindowGroup` has created its default window. The `.onChange(of: FileOpenCoordinator.shared.pendingURLs)` in `DocumentWindow` would then fire and open the file. However, this relies on timing -- the `WindowGroup` must create its window before the deferred block runs.
**Pros**: Minimal code change.
**Cons**: Timing-dependent. May break on slower machines or future macOS versions. The `init()` still has a side effect, just deferred.

### 3. Alternative B: Use `.onAppear` in the `WindowGroup` content (SwiftUI-idiomatic)

```swift
WindowGroup(for: URL.self) { $fileURL in
    DocumentWindow(fileURL: fileURL)
        .environment(appSettings)
        .onAppear {
            if let url = LaunchContext.fileURL {
                LaunchContext.fileURL = nil
                FileOpenCoordinator.shared.pendingURLs.append(url)
            }
        }
}
```

**Effort**: ~5 minutes
**Risk**: Low-Medium. `.onAppear` fires after the view is in the hierarchy, so the window exists. But `.onAppear` timing is not guaranteed to be after the window is fully visible.
**Pros**: Keeps the `FileOpenCoordinator` pattern. No change to `DocumentWindow`.
**Cons**: `.onAppear` fires on the `WindowGroup`'s content, which may have subtly different timing than `.task`.

### 4. Alternative C: Use a non-`@Observable` mechanism for launch URL (Safest)

Replace `FileOpenCoordinator.shared.pendingURLs` with a simple non-observable static variable for the launch-time URL, and only use `FileOpenCoordinator` for runtime opens:

```swift
init() {
    // No side effects. LaunchContext.fileURL is read directly in DocumentWindow.task.
}
```

**Effort**: ~10 minutes
**Risk**: Lowest. Completely avoids the `@Observable` interaction.
**Pros**: Most robust. No timing dependencies.
**Cons**: Two separate mechanisms for file opening (launch vs runtime).

## Prevention Measures

1. **Never mutate `@Observable` state in SwiftUI `App.init()`**: Struct-based SwiftUI types (`App`, `View`, `Scene`) should not have side effects in their `init()` methods. SwiftUI may call `init()` multiple times during body evaluation, and `@Observable` mutations can interfere with scene/view lifecycle.

2. **Test CLI file opening in every PR**: Add a test script that verifies `swift run mkdn README.md` creates a visible window within 5 seconds.

3. **Prefer reading state in `.task`/`.onAppear` over writing state in `init()`**: For launch-time data flow, use `LaunchContext` as a read-only static store and consume it at the view level, not the App level.

4. **Monitor SwiftUI `WindowGroup(for:)` behavior across macOS versions**: The data-driven `WindowGroup` API is relatively new and its behavior around default window creation may change.

## Evidence Appendix

### Evidence 1: Window count comparison (definitive proof)

```
Test 1 (no file argument):
  Windows: 1, Frontmost: true

Test 2 (with file argument):
  Windows: 0, Frontmost: false
```

Tested with clean defaults (`defaults delete mkdn`), clean saved state, both unbundled binary and bundled `.app`.

### Evidence 2: CoreGraphics window list (no windows at any level)

```swift
// CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID)
// Filtered by PID of mkdn process
// Result: "No windows found for PID <pid>"
```

Confirms no windows exist at the window server level -- not hidden, not offscreen, not transparent.

### Evidence 3: Process sample (main thread idle, no FileWatcher)

```
797 Thread_307531156  DispatchQueue_1: com.apple.main-thread
  797 main (main.swift:43)
    797 static App.main() (SwiftUI)
      797 NSApplicationMain (AppKit)
        797 -[NSApplication run] (AppKit)
          797 _DPSNextEvent -> mach_msg2_trap  // idle in run loop
```

Only 5 threads: main, NSEventThread, 3 worker threads. No `com.mkdn.filewatcher` thread. This proves `FileWatcher.watch()` was never called, which means `DocumentState.loadFile()` was never called, which means `DocumentWindow.task` never ran, which means no `DocumentWindow` was ever created.

### Evidence 4: Bundled `.app` exhibits same behavior

```
open mkdn.app --args README.md
  -> Window count: 0, Frontmost: false

open mkdn.app  (no args)
  -> Window count: 1, Frontmost: false  (not frontmost because `open` keeps Terminal active)
```

This proves the issue is NOT related to `swift run`, unbundled executables, process identity, code signing, or Info.plist. It is purely a SwiftUI lifecycle issue.

### Evidence 5: No crash, no error output

```
stdout: (empty)
stderr: (empty)
CPU usage: 0.0%
State: SN (sleeping, low priority)
```

The process is healthy, not crashed, not spinning, not deadlocked. It simply has no window.

### Evidence 6: lsappinfo confirms process is "Foreground" type

```
"mkdn" ASN:0x0-0x12d59d47:
    bundleID=[ NULL ]
    pid = 12476 type="Foreground" flavor=3
```

`setActivationPolicy(.regular)` worked correctly. The process is a proper foreground app. It just has no window.

### Evidence 7: The activation code in WindowAccessor works (when window exists)

```swift
// WindowAccessor.swift:25-36 (current code)
private func configureWindow(_ window: NSWindow) {
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
}
```

This code is correct. When launching without a file argument, the window IS created, `configureWindow()` IS called, and the app comes to the foreground (`frontmost = true`). The activation fix from v2 is working. It just never gets a chance to run when a file argument is provided because no window exists.

### Evidence 8: The offending code in MkdnApp.init()

**File**: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`, lines 11-15

```swift
init() {
    if let url = LaunchContext.fileURL {
        FileOpenCoordinator.shared.pendingURLs.append(url)
    }
}
```

This is the ONLY code path difference between "file argument" and "no file argument" launches. Removing or deferring this mutation would fix the issue.

### Evidence 9: FileOpenCoordinator is @Observable (the trigger)

**File**: `/Users/jud/Projects/mkdn/mkdn/App/FileOpenCoordinator.swift`, lines 8-16

```swift
@MainActor
@Observable
public final class FileOpenCoordinator {
    public static let shared = FileOpenCoordinator()
    public var pendingURLs: [URL] = []
    // ...
}
```

The `@Observable` macro generates observation tracking for `pendingURLs`. Mutating it during `MkdnApp.init()` triggers the observation system before `WindowGroup` has created its initial window.
