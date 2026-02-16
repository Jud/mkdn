# Root Cause Investigation Report - default-handler-001

## Executive Summary
- **Problem**: Clicking the blue orb to set mkdn as the default Markdown viewer does not actually change the default handler; Xcode continues to open `.md` files.
- **Root Cause**: `DefaultHandlerService.registerAsDefault()` uses `Bundle.main.bundleURL` as the application URL, which only resolves to a valid `.app` bundle when the user launches from `build/mkdn.app`. When running via `swift run mkdn` or the bare `.build/debug/mkdn` binary (the typical development workflow), `Bundle.main.bundleURL` points to the `.build/debug/` directory -- not an `.app` bundle -- causing `NSWorkspace.shared.setDefaultApplication(at:toOpen:)` to silently fail with `kLSNotAnApplicationErr`. The code always returns `true` and shows a "success" overlay regardless.
- **Solution**: Use `LSSetDefaultRoleHandlerForContentType` with the bundle identifier (or the async completion-handler variant of `setDefaultApplication`) and validate the result; additionally, resolve the `.app` bundle path rather than relying on `Bundle.main.bundleURL`.
- **Urgency**: Medium -- the feature is completely non-functional during development and may also fail for end users if they run the bare binary instead of the `.app` bundle.

## Investigation Process
- **Hypotheses Tested**:
  1. **UTI mismatch** -- REJECTED. `net.daringfireball.markdown` is correctly resolved by both `UTType("net.daringfireball.markdown")` and `UTType(filenameExtension: "md")`, and macOS Spotlight metadata confirms `.md` files use this UTI.
  2. **Info.plist missing or incorrect document type declarations** -- REJECTED. `CFBundleDocumentTypes` correctly declares `net.daringfireball.markdown` with role `Editor` and rank `Default`. `UTImportedTypeDeclarations` correctly declares the UTI with extensions `md` and `markdown`.
  3. **`Bundle.main.bundleURL` resolves to wrong path when not running from `.app` bundle** -- CONFIRMED. This is the primary root cause.
  4. **`setDefaultApplication` synchronous API silently swallows errors** -- CONFIRMED. This is a contributing factor that masks the failure.
  5. **Code signing or Launch Services registration issue** -- PARTIALLY RELEVANT. The `.app` bundle has only ad-hoc linker signing and the Info.plist is "not bound" to the code signature, but this does not prevent `setDefaultApplication` from working when the correct `.app` URL is provided.
- **Key Evidence**:
  1. When `setDefaultApplication(at:toOpen:)` is called with `.build/debug/` (non-.app URL), the async variant reports `kLSNotAnApplicationErr` (OSStatus -10811). The synchronous variant silently does nothing.
  2. When called with `build/mkdn.app/` (valid `.app` bundle), the async variant succeeds and the default handler changes after ~1 second.
  3. `DefaultHandlerService.registerAsDefault()` always returns `true` regardless of outcome.

## Root Cause Analysis

### Technical Details

**File**: `mkdn/Core/Services/DefaultHandlerService.swift`

```swift
@discardableResult
public static func registerAsDefault() -> Bool {
    let appURL = Bundle.main.bundleURL          // <-- PROBLEM 1
    NSWorkspace.shared.setDefaultApplication(   // <-- PROBLEM 2
        at: appURL,
        toOpen: markdownType
    )
    return true                                  // <-- PROBLEM 3
}
```

Three compounding issues:

1. **`Bundle.main.bundleURL` is context-dependent.** When running from `swift run mkdn` or the bare binary at `.build/debug/mkdn`, `Bundle.main.bundleURL` returns the *directory containing the executable* (e.g., `/Users/jud/Projects/mkdn/.build/debug/`), not a `.app` bundle. `NSWorkspace.shared.setDefaultApplication(at:toOpen:)` requires the URL to point to a valid `.app` bundle registered with Launch Services. A bare directory fails with `kLSNotAnApplicationErr`.

2. **The synchronous `setDefaultApplication(at:toOpen:)` variant (no completion handler) silently discards errors.** The underlying Launch Services operation is asynchronous. When it fails, the error is not propagated. The async variant `setDefaultApplication(at:toOpen:completionHandler:)` would surface the `NSCocoaErrorDomain Code=256` error wrapping `kLSNotAnApplicationErr`.

3. **`registerAsDefault()` unconditionally returns `true`.** The calling code in `MkdnCommands.swift` uses this return value to display the overlay message "Default Markdown App Set", misleading the user into thinking the operation succeeded.

### Causation Chain

```
User clicks orb "Yes" button
  -> DefaultHandlerService.registerAsDefault()
    -> Bundle.main.bundleURL = .build/debug/ (NOT a .app bundle)
    -> NSWorkspace.shared.setDefaultApplication(at: .build/debug/, toOpen: markdown)
      -> Launch Services rejects: kLSNotAnApplicationErr (-10811)
      -> Synchronous API silently discards the error
    -> returns true (hardcoded)
  -> MkdnCommands shows "Default Markdown App Set" overlay
  -> User double-clicks .md file in Finder
  -> Xcode still opens (default unchanged)
```

### Why It Occurred

- The implementation assumed `Bundle.main.bundleURL` always points to a `.app` bundle, which is only true when launched from one.
- The synchronous `setDefaultApplication` API was chosen (or defaulted to by omitting the completion handler) without awareness that it silently discards errors.
- No verification step checks whether the default actually changed after the API call.
- The SPM-based build system produces a bare binary, not a `.app` bundle. The `scripts/bundle.sh` creates the `.app` bundle as a separate step.

## Proposed Solutions

### 1. Recommended: Use `LSSetDefaultRoleHandlerForContentType` with bundle identifier

```swift
public static func registerAsDefault() -> Bool {
    let bundleID = Bundle.main.bundleIdentifier ?? "com.mkdn.app"
    let result = LSSetDefaultRoleHandlerForContentType(
        "net.daringfireball.markdown" as CFString,
        .all,
        bundleID as CFString
    )
    return result == noErr
}
```

**Pros**: Works regardless of launch context (bare binary or `.app` bundle) as long as the bundle identifier is registered with Launch Services. Returns an `OSStatus` that can be checked for success. Synchronous and reliable.

**Cons**: `LSSetDefaultRoleHandlerForContentType` is deprecated since macOS 12.0 (still functional as of macOS 15). Requires the `.app` bundle to have been registered with Launch Services at least once (via `lsregister` or by opening it).

**Effort**: Small (< 30 minutes)
**Risk**: Low

### 2. Alternative: Use async `setDefaultApplication` with completion handler + hardcoded `.app` path

```swift
public static func registerAsDefault(completion: @escaping (Bool) -> Void) {
    let appURL = resolveAppBundleURL()
    NSWorkspace.shared.setDefaultApplication(
        at: appURL,
        toOpen: markdownType
    ) { error in
        completion(error == nil)
    }
}

private static func resolveAppBundleURL() -> URL {
    let mainURL = Bundle.main.bundleURL
    if mainURL.pathExtension == "app" {
        return mainURL
    }
    // Fallback: look for the .app bundle in known locations
    // e.g., ~/Applications/mkdn.app, /Applications/mkdn.app,
    //        or relative to the project at build/mkdn.app
    // ...
}
```

**Pros**: Uses the modern, non-deprecated API. Provides error feedback.

**Cons**: More complex. Requires resolving the `.app` bundle URL when not running from one, which is fragile. Async API complicates the UI flow (need to update overlay after completion, not immediately).

**Effort**: Medium (1-2 hours)
**Risk**: Medium (URL resolution logic may be fragile)

### 3. Hybrid: Use `LSSetDefaultRoleHandlerForContentType` with `isDefault()` verification

Combine the reliable old API for setting the default with a post-check using `isDefault()` (after a small delay) to confirm success and surface accurate feedback to the user.

**Effort**: Small-Medium (30-60 minutes)
**Risk**: Low

## Prevention Measures

1. **Always test registration from the actual user-facing context** -- when the app is launched as a `.app` bundle, not via `swift run`.
2. **Never ignore API return values or errors.** The synchronous `setDefaultApplication` variant should be avoided in favor of the completion-handler version, or `LSSetDefaultRoleHandlerForContentType` which returns an `OSStatus`.
3. **Add a verification step** -- after attempting to register, call `isDefault()` (possibly after a short delay) to confirm the change took effect before showing success UI.
4. **Add a note to the build/run documentation** that `swift run mkdn` does not create a `.app` bundle, so features depending on Launch Services registration (like "set as default") require running from the bundled `.app`.

## Evidence Appendix

### E1: Synchronous API with non-.app URL (silent failure)

```
Calling synchronous setDefaultApplication with: file:///Users/jud/Projects/mkdn/.build/debug/
Default after call: Xcode-16.3.0.app   <-- UNCHANGED
```

### E2: Async API with non-.app URL (error surfaced)

```
ERROR setting default: Error Domain=NSCocoaErrorDomain Code=256
  "The file couldn't be opened."
  UserInfo={NSUnderlyingError=0x600001afda70
    {Error Domain=NSOSStatusErrorDomain Code=-10811
     "kLSNotAnApplicationErr: Item needs to be an application, but is not"}}
```

### E3: Async API with correct .app URL (success)

```
Async version with .app bundle: Success!
Default is now: /Users/jud/Projects/mkdn/build/mkdn.app
```

### E4: LSSetDefaultRoleHandlerForContentType (works from any context)

```
LSSetDefaultRoleHandlerForContentType result: 0
Success (0)?: true
Default handler: com.mkdn.app
```

### E5: Synchronous API timing (async internal behavior)

```
Before:      Xcode-16.3.0.app
Immediately: Xcode-16.3.0.app   <-- Still old value
After 1.5s:  mkdn.app            <-- Changed after delay
```

### E6: Launch Services registration for mkdn

```
path:        /Users/jud/Projects/mkdn/build/mkdn.app
identifier:  com.mkdn.app
flags:       inactive  imported  trusted
Signature:   adhoc (linker-signed)
Info.plist:  not bound
```

### E7: Code path in DefaultHandlerService.swift

```swift
// Line 15-22: registerAsDefault()
let appURL = Bundle.main.bundleURL    // .build/debug/ when running via swift run
NSWorkspace.shared.setDefaultApplication(
    at: appURL,                       // Fails silently - not a .app bundle
    toOpen: markdownType
)
return true                           // Always reports success
```
