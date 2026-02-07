# Design Decisions: Mermaid Diagram Rendering Re-Architecture

**Feature ID**: mermaid-rearchitect
**Created**: 2026-02-07

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Scroll pass-through mechanism | hitTest gating on NSView container | Simplest approach: returning nil from hitTest causes all events to pass to parent responder chain. Zero custom gesture code. Directly satisfies FR-005 and AC-005.2. | (a) Disable WKWebView userInteractionEnabled -- doesn't exist on macOS NSView; (b) NSEvent local monitor forwarding -- complex, replicates the problem being replaced; (c) Override scrollWheel on container NSView -- partial, doesn't handle all event types |
| D2 | HTML content delivery to WKWebView | loadHTMLString with token substitution | Self-contained: template + code + theme in a single HTML string. baseURL points to Resources/ so local script tags resolve. No file URL permission issues. | (a) loadFileURL -- requires file access grants, harder to inject dynamic code/theme; (b) JS postMessage for code injection -- requires two-phase load (template first, then inject code), adds latency and complexity |
| D3 | WKWebView process model | Shared WKProcessPool across all diagrams | Reduces memory: all WKWebViews share one web content process instead of each spawning its own. Standard practice for multiple WKWebViews in one app. | (a) Default (one process per WKWebView) -- higher memory overhead, no benefit; (b) WKWebView reuse/pooling -- explicitly out of scope per requirements |
| D4 | Theme color format for JS | Hardcoded hex lookup in MermaidThemeMapper keyed by AppTheme case | SwiftUI Color cannot be reliably converted to hex at runtime without NSColorSpace gymnastics. The hex values are documented in SolarizedDark.swift / SolarizedLight.swift comments. A static mapping is correct, simple, and testable. | (a) Runtime Color-to-hex via NSColor -- fragile, depends on color space; (b) Add hex properties to ThemeColors -- pollutes ThemeColors with web-specific concerns; (c) Store hex alongside Color in SolarizedDark/Light -- doubles the definition surface |
| D5 | Theme change re-rendering | In-place JS re-evaluation via evaluateJavaScript | Avoids destroying and recreating WKWebView (expensive). Re-initializes Mermaid theme and re-runs render in the existing web context. Faster and avoids white flash. | (a) Recreate WKWebView on theme change -- expensive, causes visible teardown/rebuild; (b) Reload HTML string -- simpler but still involves full page load cycle |
| D6 | Maximum diagram height | 600 points | Balances readability (most diagrams fit within 600pt) with preventing extremely tall diagrams from dominating the scroll. The current implementation uses 400pt which clips complex diagrams. 600pt provides more room while maintaining document flow. | (a) 400pt (current) -- too small for sequence diagrams; (b) 800pt -- too dominant in normal documents; (c) No max (unlimited) -- could make single diagram consume entire viewport |
| D7 | Focus visual indicator | 2pt accent-colored border (RoundedRectangle stroke) | Consistent with Solarized blue accent. Thin enough not to distract during reading, visible enough to confirm state. Uses existing theme.colors.accent. | (a) Background glow/shadow -- harder to see on dark themes; (b) Thicker border -- too visually heavy; (c) No indicator -- violates NFR-007, user cannot confirm focus state |
| D8 | Click-outside unfocus mechanism | NSEvent.addLocalMonitorForEvents in Coordinator | Reliable: captures all left-click events app-wide, checks if click is inside diagram bounds. Installed only when focused, removed when unfocused or on teardown. | (a) SwiftUI @FocusState -- does not reliably track non-focusable views; (b) Global tap gesture on parent view -- requires invasive changes to MarkdownPreviewView; (c) NSEvent.addGlobalMonitorForEvents -- overkill, monitors outside the app |
| D9 | JXKit dependency handling | No action needed | JXKit is referenced in KB documentation but is NOT present in Package.swift. The existing MermaidRenderer.swift imports JavaScriptCore (system framework) directly. The KB modules.md entry is outdated. | (a) Remove JXKit from Package.swift -- not needed, it's not there |
| D10 | Mermaid.js version strategy | Bundle specific version as static resource | Provides offline support, version stability, and reproducible builds. The mermaid.min.js file is committed to the repository. Version updates are explicit. | (a) CDN loading -- requires network, violates BR-002; (b) SPM package for Mermaid.js -- no such package exists; (c) Download at build time -- fragile CI, requires network |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| NSViewRepresentable pattern | Follow WindowAccessor / ScrollPhaseMonitor pattern (NSView subclass + Coordinator) | Codebase patterns | Consistent with existing codebase, proven approach |
| State management in MermaidBlockView | @State for local state, @Environment(AppSettings.self) for theme | KB patterns.md | Matches existing view state patterns |
| Error UI pattern | Warning icon + descriptive message in rounded rect container | Existing MermaidBlockView.swift | Preserves existing visual language |
| Loading UI pattern | ProgressView(controlSize: .small) + caption text | Existing MermaidBlockView.swift | Preserves existing visual language |
| Mermaid theme approach | 'base' theme with themeVariables | Mermaid.js documentation (standard approach) | Only approach that allows full color customization |
| Swift concurrency for WKWebView | @MainActor, @preconcurrency import WebKit if needed | KB patterns.md, MEMORY.md | WKWebView must be on main actor per WebKit requirements and Swift 6 rules |
| Test framework | Swift Testing (@Test, #expect, @Suite) | KB patterns.md | Codebase standard |
| Resource bundling | .copy() rules in Package.swift | Existing Package.swift pattern | Matches existing mermaid.min.js resource approach |
| File organization | Core/Mermaid/ for infrastructure, Features/Viewer/Views/ for view | KB modules.md | Matches existing directory structure |
