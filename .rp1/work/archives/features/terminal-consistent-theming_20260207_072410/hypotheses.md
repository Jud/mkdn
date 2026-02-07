# Hypothesis Document: terminal-consistent-theming
**Version**: 1.0.0 | **Created**: 2026-02-07T13:00:00Z | **Status**: VALIDATED

## Hypotheses

### HYP-001: beautiful-mermaid renderMermaid accepts theme options
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: beautiful-mermaid's renderMermaid() JavaScript function accepts an options object with a 'theme' property to control dark/light rendering output.
**Context**: Core to the feature -- if Mermaid diagrams cannot be themed, the entire consistent-theming feature for Mermaid blocks would require a different approach (CSS post-processing, SVG manipulation, etc.).
**Validation Criteria**:
- CONFIRM if: beautifulMermaid.renderMermaid(code, {theme: 'dark'}) produces SVG with dark-themed colors different from renderMermaid(code) or renderMermaid(code, {theme: 'default'}). Check the mermaid.min.js bundle resource or its source repository for the function signature.
- REJECT if: beautifulMermaid.renderMermaid() accepts only a single string argument, or the options object is ignored, or the function throws when given a second argument.
**Suggested Method**: CODE_EXPERIMENT

### HYP-002: NSApp.effectiveAppearance available during AppSettings.init()
**Risk Level**: MEDIUM
**Status**: CONFIRMED
**Statement**: NSApp.effectiveAppearance is available and returns the correct system appearance during AppSettings.init() in the SwiftUI App lifecycle on macOS 14+.
**Context**: Would allow AppSettings to initialize systemColorScheme to the correct value immediately, rather than defaulting to .dark and waiting for ContentView.onAppear to bridge the SwiftUI colorScheme environment.
**Validation Criteria**:
- CONFIRM if: In a macOS 14+ SPM-based SwiftUI app, NSApp is non-nil during @Observable init when created as @State in the App struct, and effectiveAppearance matches the system dark/light setting.
- REJECT if: NSApp is nil at that point, or effectiveAppearance always returns .aqua regardless of system dark mode setting.
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-07T13:01:00Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

The hypothesis statement is **partially inaccurate in its framing but CONFIRMED in substance**. The API does not accept a `theme` string property (e.g., `{theme: 'dark'}`). Instead, it accepts individual color properties directly as the options object. This is actually better than what was hypothesized -- it provides fine-grained control.

**API Signature** (from minified source analysis and official documentation):
```typescript
renderMermaid(text: string, options?: RenderOptions): Promise<string>

interface RenderOptions {
  bg?: string           // Background color (default: #FFFFFF)
  fg?: string           // Foreground color (default: #27272A)
  line?: string         // Edge/connector color (optional)
  accent?: string       // Arrow heads, highlights (optional)
  muted?: string        // Secondary text, labels (optional)
  surface?: string      // Node fill tint (optional)
  border?: string       // Node stroke color (optional)
  font?: string         // Font family (default: Inter)
  transparent?: boolean // Render with transparent bg (default: false)
}
```

**Built-in Solarized themes available** in `beautifulMermaid.THEMES`:
- `"solarized-dark"`: `{bg:"#002b36", fg:"#839496", line:"#586e75", accent:"#268bd2", muted:"#586e75"}`
- `"solarized-light"`: `{bg:"#fdf6e3", fg:"#657b83", line:"#93a1a1", accent:"#268bd2", muted:"#93a1a1"}`

**Code experiment results** (JavaScriptCore, same engine used in production):
- Default render (no options): SVG uses `--bg:#FFFFFF;--fg:#27272A` -- white background
- Themed render (solarized-dark colors): SVG uses `--bg:#002b36;--fg:#839496;--line:#586e75;--accent:#268bd2;--muted:#586e75`
- SVGs are structurally different (1874 vs 1922 chars), confirming the theme colors are embedded in the output
- Colors are injected as CSS custom properties in the SVG `style` attribute, enabling clean theming

**Current codebase call** (`mkdn/Core/Mermaid/MermaidRenderer.swift:63`):
```swift
let promise = try jsContext.eval("beautifulMermaid.renderMermaid(\"\(escaped)\")")
```
This passes only the mermaid code string. Adding the options object is straightforward:
```swift
let promise = try jsContext.eval("beautifulMermaid.renderMermaid(\"\(escaped)\", {bg:\"#002b36\",fg:\"#839496\",...})")
```

**All 14 built-in theme names**: zinc-dark, tokyo-night, tokyo-night-storm, tokyo-night-light, catppuccin-mocha, catppuccin-latte, nord, nord-light, dracula, github-light, github-dark, solarized-light, solarized-dark, one-dark.

**Sources**:
- `mkdn/Core/Mermaid/MermaidRenderer.swift:63` -- current single-argument call
- `mkdn/Resources/mermaid.min.js:76` -- `async function Tn(e,t={})` confirms two-argument signature
- `mkdn/Resources/mermaid.min.js` -- `Li(t)` function extracts `{bg, fg, line, accent, muted, surface, border}` from options
- `mkdn/Resources/mermaid.min.js` -- `THEMES` object contains `solarized-dark` and `solarized-light` presets
- https://github.com/lukilabs/beautiful-mermaid -- official repository
- https://www.npmjs.com/package/beautiful-mermaid -- npm package
- Code experiment: `/tmp/hypothesis-terminal-consistent-theming/test_mermaid.swift`

**Implications for Design**:
- Mermaid diagram theming is fully supported with zero library changes needed.
- The existing `renderMermaid()` call just needs a second argument with theme colors.
- The Solarized Dark/Light color presets are already built into beautiful-mermaid, matching the app's existing theme system exactly.
- Cache key should incorporate theme colors to avoid stale cached SVGs when the theme changes.
- The `transparent` option may be useful if diagrams should blend with the app's background rather than having their own bg fill.

### HYP-002 Findings
**Validated**: 2026-02-07T13:01:30Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

In this specific codebase, `NSApp` is guaranteed to be non-nil during `AppSettings.init()` because the entry point (`mkdnEntry/main.swift:42`) explicitly calls `NSApplication.shared.setActivationPolicy(.regular)` before `MkdnApp.main()`. The `NSApplication.shared` accessor creates the singleton, so by the time SwiftUI creates the `@State private var appSettings = AppSettings()` property, NSApp already exists.

**Code experiment** (macOS, same Swift runtime):
```
NSApp is nil: false
effectiveAppearance: NSAppearanceName(_rawValue: NSAppearanceNameDarkAqua)
bestMatch: NSAppearanceName(_rawValue: NSAppearanceNameDarkAqua)
```
The test confirms `NSApp.effectiveAppearance` returns the correct system appearance (darkAqua on a dark mode system) even before the full app run loop starts.

**Current codebase approach** (`mkdn/App/AppSettings.swift:28`):
```swift
public var systemColorScheme: ColorScheme = .dark
```
This hard-codes the default to `.dark`. The actual system appearance is only bridged later via `ContentView.onAppear` (`mkdn/App/ContentView.swift:61`):
```swift
.onAppear {
    appSettings.systemColorScheme = colorScheme
}
```

**Entry point sequence** (`mkdnEntry/main.swift:34-43`):
```swift
let cli = try MkdnCLI.parse()
// ... file validation ...
NSApplication.shared.setActivationPolicy(.regular)  // <-- creates NSApp
MkdnApp.main()  // <-- triggers App init -> @State init -> AppSettings.init()
```

**Important caveat**: While `NSApp.effectiveAppearance` works correctly here, the current architecture uses SwiftUI's `@Environment(\.colorScheme)` bridge pattern, which is the idiomatic SwiftUI approach. Using `NSApp.effectiveAppearance` in `AppSettings.init()` would be an alternative that provides correct initial values but introduces a direct AppKit dependency in the model layer. The SwiftUI bridge pattern keeps AppSettings testable without AppKit mocking.

**Sources**:
- `mkdnEntry/main.swift:42` -- `NSApplication.shared.setActivationPolicy(.regular)` creates NSApp before app launch
- `mkdn/App/AppSettings.swift:28` -- current `.dark` default for `systemColorScheme`
- `mkdn/App/ContentView.swift:60-64` -- SwiftUI colorScheme bridge via onAppear/onChange
- https://developer.apple.com/documentation/appkit/nsapplication/1428360-shared -- NSApplication.shared creates singleton
- https://developer.apple.com/documentation/appkit/nsapplication/effectiveappearance -- effectiveAppearance docs
- Code experiment: `/tmp/hypothesis-terminal-consistent-theming/` directory

**Implications for Design**:
- `NSApp.effectiveAppearance` could be used in `AppSettings.init()` to set the correct initial `systemColorScheme` instead of hard-coding `.dark`, eliminating the brief flash-of-wrong-theme on first render.
- The existing SwiftUI `colorScheme` bridge in ContentView should be kept for ongoing appearance change detection.
- A hybrid approach is possible: use `NSApp.effectiveAppearance` for initial value, SwiftUI `@Environment(\.colorScheme)` for updates.
- For Mermaid theming specifically, the initial theme value matters because diagrams may render before `ContentView.onAppear` fires.

## Summary

| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | CONFIRMED | renderMermaid accepts options with {bg, fg, line, accent, muted, surface, border}. Built-in solarized-dark/light presets match app themes. No library changes needed. |
| HYP-002 | MEDIUM | CONFIRMED | NSApp.effectiveAppearance works during AppSettings.init() in this codebase. Can set correct initial theme instead of defaulting to .dark. |
