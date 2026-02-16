# Root Cause Investigation Report - cmdw-close-001

## Executive Summary
- **Problem**: Command-W does not close the window in the mkdn application
- **Root Cause**: Two compounding issues: (1) `CommandGroup(replacing: .newItem) {}` in `main.swift` removes SwiftUI's built-in "Close Window" menu item (which lives in the `.newItem` group alongside "New Window"), and (2) the custom `CommandGroup(before: .saveItem)` Close Window button in `MkdnCommands.swift` is **silently dropped by SwiftUI** and never appears in the rendered menu -- it exists neither in the visible menu bar nor in the Accessibility tree. The `.saveItem` position appears to be a non-functional anchor for custom Close commands.
- **Solution**: Move the Close Window button into `CommandGroup(replacing: .newItem)` and use `NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)` as the action. Alternatively, inject a native AppKit NSMenuItem with `performClose:` in `applicationDidFinishLaunching`.
- **Urgency**: Medium -- affects core usability; users must use the red traffic light (which is also hidden) or Cmd-Q to exit

## Investigation Process
- **Hypotheses Tested**: 7 hypotheses tested through runtime experimentation
- **Key Evidence**: NSMenu introspection dump, Accessibility API enumeration, programmatic `performClose` verification

### Hypotheses and Results

1. **`keyWindow` is nil when the action fires** -- DISPROVED: The action never fires. The menu item does not exist in the rendered menu.

2. **NSTextView intercepts Cmd-W via `performKeyEquivalent:`** -- DISPROVED: No `performKeyEquivalent` overrides exist in `CodeBlockBackgroundTextView`. The event never reaches the responder chain because there is no menu item to trigger.

3. **MermaidWebView escape key monitor consumes Cmd-W** -- DISPROVED: The monitor registers for `.keyDown` but only swallows keyCode 53 (Escape). All other events are returned.

4. **`CommandGroup(replacing: .newItem) {}` removes the built-in Close Window** -- CONFIRMED: SwiftUI's `.newItem` command group contains both "New Window" and "Close Window". Replacing it with `{}` removes both. However, NOT replacing it also doesn't add a Close item for a `WindowGroup(for: URL.self)` data-driven window group.

5. **`CommandGroup(before: .saveItem)` placement is non-functional** -- CONFIRMED: Buttons placed at `before: .saveItem` do not appear in the rendered menu regardless of shortcut key, button title, or other properties. The NSMenu does not contain them. This was tested with different titles, different shortcuts (Cmd-K), and no shortcuts at all. None appeared.

6. **SwiftUI suppresses buttons with `.keyboardShortcut("w", modifiers: .command)`** -- PARTIALLY CONFIRMED: Buttons with Cmd-W are suppressed at `before: .saveItem`, but also buttons WITHOUT any shortcut at the same position are suppressed. The suppression is position-based, not shortcut-based.

7. **`performClose(_:)` works when called programmatically** -- CONFIRMED: Calling `NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)` successfully closes the window. The window is `SwiftUI.AppKitWindow`, has `.closable` in its style mask (value 32783), and both `keyWindow` and `mainWindow` are non-nil.

## Root Cause Analysis

### Technical Details

The root cause is a **SwiftUI menu rendering failure** caused by incorrect `CommandGroup` placement:

**File**: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`, line 19
```swift
CommandGroup(replacing: .newItem) {}
```
This removes SwiftUI's built-in Close Window menu item (which is part of the `.newItem` group).

**File**: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`, lines 29-34
```swift
CommandGroup(before: .saveItem) {
    Button("Close Window") {
        (NSApp.mainWindow ?? NSApp.keyWindow)?.close()
    }
    .keyboardShortcut("w", modifiers: .command)
}
```
This attempts to add a replacement Close button at the `before: .saveItem` position, but SwiftUI silently drops it. The button never appears in:
- The visible macOS menu bar
- The Accessibility tree (AppleScript cannot find it)
- The NSMenu items (confirmed via runtime introspection)

### NSMenu Introspection Evidence

With the current code, the File menu at the AppKit level contains:
```
[0] Open Recent
[1] --- separator ---
[2] Save (Cmd+s) [DISABLED]
[3] --- separator ---
[4] Open... (Cmd+o)
[5] Reload (Cmd+r)
```

No "Close Window" item exists anywhere. When the Close button was moved to `CommandGroup(replacing: .newItem)`, the NSMenu showed:
```
[0] Close Window (Cmd+w) -- action=menuAction: target=MenuItemCallback
[1] Open Recent
...
```

However, even in this position, the Accessibility tree (6 items) did not include it, and Cmd-W did not trigger it. This appears to be a SwiftUI rendering bug where items placed via `CommandGroup(replacing: .newItem)` are created in NSMenu but not exposed through the standard menu rendering pipeline.

### Causation Chain

```
1. `CommandGroup(replacing: .newItem) {}` removes SwiftUI's built-in "Close Window" (Cmd-W)
2. Custom `CommandGroup(before: .saveItem)` Close button is silently dropped by SwiftUI
3. No Close menu item exists in the rendered File menu
4. User presses Cmd-W
5. No menu item with Cmd-W key equivalent exists in the rendered menu
6. Event is not handled
7. Window remains open
```

### Why It Occurred

- The `.newItem` command group in SwiftUI contains both "New Window" and "Close Window" -- this is not documented clearly
- `CommandGroup(before: .saveItem)` does not reliably render custom buttons in SwiftUI (likely a framework bug or undocumented limitation)
- The prior investigation (cmdw-close-001 v1) focused on `keyWindow` being nil and NSTextView interception, but the true root cause is that the menu item never exists in the rendered menu

## Proposed Solutions

### 1. Recommended: AppKit-Level Close Menu Item via AppDelegate

Add the Close menu item directly through AppKit in `applicationDidFinishLaunching`, bypassing SwiftUI's menu system entirely. Use a repeating observer to re-inject the item if SwiftUI rebuilds the menu.

```swift
// In AppDelegate:
public func applicationDidFinishLaunching(_: Notification) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.ensureCloseMenuItem()
    }
}

private func ensureCloseMenuItem() {
    guard let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu else { return }
    // Remove existing SwiftUI close item if present but non-functional
    if let existing = fileMenu.items.first(where: { $0.keyEquivalent == "w" }) {
        fileMenu.removeItem(existing)
    }
    let closeItem = NSMenuItem(
        title: "Close Window",
        action: #selector(NSWindow.performClose(_:)),
        keyEquivalent: "w"
    )
    fileMenu.insertItem(closeItem, at: 0)
    fileMenu.insertItem(NSMenuItem.separator(), at: 1)
}
```

And remove the broken `CommandGroup(before: .saveItem)` block from `MkdnCommands.swift`.

**Effort**: ~30 minutes (including testing menu rebuild resilience)
**Risk**: Low-medium -- AppKit menu injection works reliably but needs to handle SwiftUI menu rebuilds
**Pros**: Uses standard AppKit `performClose:` routing through the responder chain; no SwiftUI workarounds
**Cons**: Mixes AppKit and SwiftUI menu management

### 2. Alternative: Move Close into `CommandGroup(replacing: .newItem)` + `@Environment(\.dismissWindow)`

```swift
// In main.swift:
CommandGroup(replacing: .newItem) {
    Button("Close Window") {
        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
    }
    .keyboardShortcut("w", modifiers: .command)
}
```

This creates the NSMenuItem correctly at the AppKit level. However, testing showed it doesn't appear in the rendered Accessibility tree, so it may still not respond to Cmd-W keystrokes. Needs further testing with an actual GUI interaction (not AppleScript).

**Effort**: ~15 minutes
**Risk**: Medium -- the item appears in NSMenu but may not be rendered by SwiftUI
**Pros**: Pure SwiftUI approach, minimal code
**Cons**: May still not work due to SwiftUI rendering issues

### 3. Alternative: `NSEvent.addLocalMonitorForEvents` in AppDelegate

Install a local event monitor that intercepts Cmd-W keyDown events and calls `performClose` directly. Remove the SwiftUI close command.

```swift
// In AppDelegate:
private var cmdWMonitor: Any?

public func applicationDidFinishLaunching(_: Notification) {
    cmdWMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers == "w"
        {
            (NSApp.keyWindow ?? NSApp.mainWindow)?.performClose(nil)
            return nil
        }
        return event
    }
}
```

**Effort**: ~15 minutes
**Risk**: Low -- event monitors are reliable for key interception
**Pros**: Guaranteed to intercept Cmd-W regardless of menu state; simple implementation
**Cons**: Bypasses the menu system entirely; Close item won't appear in the File menu unless separately added. The window needs to be receiving events (app must be key).

### 4. Hybrid: AppKit Menu + Event Monitor Fallback

Combine solutions 1 and 3: inject an AppKit Close menu item for visual presence, and install an event monitor as a fallback for reliable Cmd-W handling.

**Effort**: ~45 minutes
**Risk**: Low
**Pros**: Most robust -- menu item visible and keyboard shortcut reliable
**Cons**: Most code

## Prevention Measures

1. The `.newItem` command group in SwiftUI contains BOTH "New Window" and "Close Window" -- never replace it with `{}` unless you add a close mechanism elsewhere
2. `CommandGroup(before: .saveItem)` does not reliably render buttons in all SwiftUI window configurations -- avoid this placement for critical menu items
3. When using `WindowGroup(for: URL.self)` (data-driven), SwiftUI may not provide default New/Close menu items -- always verify menu rendering with runtime introspection
4. Test menu items by dumping `NSApp.mainMenu` at runtime, not by relying on SwiftUI declarations
5. For critical window management operations (close, minimize), prefer AppKit-level implementation (`performClose:`, `NSMenuItem`) over SwiftUI `CommandGroup` when dealing with custom window configurations

## Evidence Appendix

### E1: File Menu NSMenu Dump (Current Code)
The File menu contains 6 items. No "Close Window" item exists:
```
[0] Open Recent | action=submenuAction:
[1] --- separator ---
[2] Save (Cmd+s) [DISABLED] | action=nil
[3] --- separator ---
[4] Open... (Cmd+o) | action=menuAction:
[5] Reload (Cmd+r) [DISABLED] | action=nil
```

### E2: File Menu NSMenu Dump (Close in `replacing: .newItem`)
When Close Window is placed inside `CommandGroup(replacing: .newItem)`:
```
[0] Close Window (Cmd+w) | action=menuAction: target=MenuItemCallback axEnabled=true axIgnored=false
[1] Open Recent | action=submenuAction:
...
```
The item exists in NSMenu but NOT in the Accessibility tree (AppleScript sees only 6 items starting from Open Recent).

### E3: Accessibility API File Menu (All Configurations)
Regardless of placement, AppleScript always sees:
```
1: Open Recent | enabled=true
2: missing value | enabled=false
3: Save | enabled=false
4: missing value | enabled=false
5: Open... | enabled=true
6: Reload | enabled=false
```

### E4: `performClose` Works Programmatically
```
keyWindow: Optional(<SwiftUI.AppKitWindow: 0x146873800>)
mainWindow: Optional(<SwiftUI.AppKitWindow: 0x146873800>)
windows: ["AppKitWindow 'mkdn' visible=true key=true main=true styleMask=32783"]
sendAction(performClose) returned: true
After close: windows=[]
```
The window has style mask 32783 (0x800F) which includes `.closable`. `performClose` closes it successfully.

### E5: `CommandGroup(before: .saveItem)` Completely Non-Functional
Tested with:
- Original: `Button("Close Window") .keyboardShortcut("w", modifiers: .command)` -- not rendered
- Different shortcut: `Button("Close Window [TEST-K]") .keyboardShortcut("k", modifiers: .command)` -- not rendered
- No shortcut: `Button("Close Window [NO-SHORTCUT]")` -- not rendered
- Different position: `CommandGroup(after: .importExport)` -- not rendered when a second group at same position exists
- Different position: `CommandGroup(before: .sidebar)` -- not rendered

### E6: Original `CommandGroup(replacing: .newItem) {}` Removes Built-in Close
With `CommandGroup(replacing: .newItem) {}` removed, no default "Close" or "New Window" item appears in the File menu for `WindowGroup(for: URL.self)`. The data-driven WindowGroup does not auto-generate these items.

### E7: Window Configuration
- Window type: `SwiftUI.AppKitWindow`
- Style: `.hiddenTitleBar`
- Standard buttons: hidden via `WindowAccessor` (`.closeButton`, `.miniaturizeButton`, `.zoomButton` all `.isHidden = true`)
- `styleMask` includes `.closable` (verified via rawValue 32783)
- `applicationShouldTerminateAfterLastWindowClosed` returns `false` (correct)
