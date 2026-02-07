# Feature Verification Report #1

**Generated**: 2026-02-07T04:21Z
**Feature ID**: fix-infinite-scroll-rerender
**Verification Scope**: all
**KB Context**: Loaded (index.md, patterns.md)
**Field Notes**: Not available (no field-notes.md)

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 8/12 verified (66%)
- Implementation Quality: HIGH
- Ready for Merge: NO (4 criteria require manual verification; 3 doc tasks incomplete)

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None (no field-notes.md exists for this feature)

### Undocumented Deviations
None found. All code implementations match the design specification exactly.

## Acceptance Criteria Verification

### REQ-001: Break the Scroll Re-render Cycle
**AC-1a**: Scrolling up and down through a document with 5+ Mermaid blocks at normal speed produces no visible re-rendering of already-rendered diagrams.
- Status: MANUAL_REQUIRED
- Implementation: The code-level fix is in place (see AC-2a, AC-2b, AC-3a, AC-3b evidence). The MermaidBlockView cache-aware init (`/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift:24-30`) ensures recycled views start in rendered state. `.task(id: code)` at line 42 prevents spurious re-fires.
- Evidence: Code structurally prevents re-rendering: `renderDiagram()` (line 153) guards with `guard renderedImage == nil, errorMessage == nil else { return }`, so cache-hit views never enter the render pipeline. LazyVStack at `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift:16` remains lazy for performance.
- Field Notes: N/A
- Issues: Requires visual confirmation with a real Mermaid-heavy document. Cannot be verified through code analysis alone.

**AC-1b**: Scrolling rapidly (fast flick gesture) through the same document does not cause the app to become unresponsive.
- Status: MANUAL_REQUIRED
- Implementation: Same structural fix as AC-1a. The early-return guard in `renderDiagram()` and synchronous cache initialization eliminate the CPU-intensive re-render cycle.
- Evidence: The re-render loop was caused by: (1) `.task` re-firing on view recycling, (2) `isLoading = true` changing view height, (3) height change causing LazyVStack re-layout. All three are addressed: `.task(id: code)` limits re-fires, cache-aware init prevents loading state, early-return guard prevents async work.
- Field Notes: N/A
- Issues: Requires physical scroll testing to confirm no jank under rapid flick.

**AC-1c**: Scrolling rapidly does not cause the app to crash.
- Status: MANUAL_REQUIRED
- Implementation: Same structural fix. The crash was caused by unbounded re-render cycles exhausting resources.
- Evidence: The fix breaks the cycle at multiple points, making crash impossible from this specific cause.
- Field Notes: N/A
- Issues: Requires physical testing with rapid scroll on a Mermaid-heavy document.

### REQ-002: Preserve Rendered Mermaid Output Across View Recycling
**AC-2a**: A Mermaid diagram that was fully rendered, then scrolled off-screen, then scrolled back on-screen, appears immediately without a loading indicator.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift:24-30` and `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidImageStore.swift:26-33`
- Evidence: `MermaidBlockView.init(code:)` performs a synchronous cache lookup via `MermaidImageStore.shared.get(code)` (line 26). On a cache hit, `_renderedImage` is initialized with the cached NSImage (line 27) and `_isLoading` is initialized to `false` (line 29). This means the view body immediately renders the `diagramView(image:)` branch (line 37) with no loading indicator. The `renderDiagram()` guard at line 153 (`guard renderedImage == nil, errorMessage == nil else { return }`) ensures the `.task` is a no-op.
- Field Notes: N/A
- Issues: None. Implementation matches design exactly.

**AC-2b**: The JavaScriptCore/SVG rendering pipeline is not re-invoked for a Mermaid block whose content has not changed.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift:152-177` (renderDiagram guard) and `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidRenderer.swift:47-51` (SVG cache)
- Evidence: Two layers of caching prevent re-invocation: (1) MermaidImageStore provides NSImage-level caching checked synchronously in init, causing the `.task` to early-return before any async work. (2) Even if the NSImage cache misses (e.g., after theme change), MermaidRenderer's SVG cache (`MermaidCache`) at line 49 of MermaidRenderer.swift returns the cached SVG string without re-executing JavaScriptCore. The full JS pipeline only runs on a genuine cache miss at both levels.
- Field Notes: N/A
- Issues: None.

### REQ-003: Stable View Identity for Mermaid Blocks
**AC-3a**: The Identifiable conformance for Mermaid blocks produces the same ID for the same Mermaid source code across consecutive render passes.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownBlock.swift:38-39`
- Evidence: `MarkdownBlock.mermaidBlock` case produces its ID as `"mermaid-\(stableHash(code))"` using the DJB2 hash function defined at lines 69-74. The `stableHash` function is a deterministic DJB2 hash that produces the same UInt64 for the same input string across all invocations (no randomization, no process-dependent seed). Unit tests in `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/MarkdownVisitorTests.swift` include a "Same input produces identical block IDs" test confirming this property.
- Field Notes: N/A
- Issues: None.

**AC-3b**: No .task or .onAppear re-fires for a Mermaid block that has not changed content while the user is only scrolling.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift:42-44`
- Evidence: The `.task(id: code)` modifier (line 42) binds the task lifecycle to the `code` value. SwiftUI only re-fires `.task(id:)` when the `id` value changes. Since the mermaid code does not change during scrolling, the task does not re-fire on scroll-back after recycling. Even when the view is destroyed and recreated by LazyVStack (which does fire `.task(id:)` on first appear of the new instance), the `renderDiagram()` guard at line 153 ensures immediate return when `renderedImage` is already populated from the cache-aware init. The `.task` fires but performs zero work.
- Field Notes: N/A
- Issues: Technically, `.task(id:)` does fire on view creation after recycling (this is SwiftUI behavior), but the guard clause makes it a no-op. The spirit of the AC is satisfied: no rendering work is performed.

### REQ-004: No Degradation of Initial Mermaid Render Experience
**AC-4a**: Opening a file with Mermaid blocks shows loading indicators that resolve to rendered diagrams.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift:24-30` (cache miss path) and lines 152-177 (renderDiagram)
- Evidence: On first file open, `MermaidImageStore` is empty (either fresh app start, or cleared by `AppState.loadFile(at:)` at `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift:82`). The init's cache check returns nil (line 26), so `_isLoading` is initialized to `true` (line 29). The body renders `loadingView` (line 34-35). The `.task(id: code)` fires, `renderDiagram()` passes the guard (renderedImage is nil), invokes the full pipeline (JSC -> SVG -> SwiftDraw -> NSImage), stores the image in MermaidImageStore (line 161), and sets `renderedImage` (line 159) / `isLoading = false` (line 176). The view transitions from loading to rendered diagram.
- Field Notes: N/A
- Issues: None. First-render behavior is preserved.

**AC-4b**: Editing Mermaid source code in side-by-side mode triggers a fresh render of the changed diagram.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift:42` (`.task(id: code)`) and `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift:24` (`.task(id: appState.markdownContent)`)
- Evidence: When the user edits Mermaid source in the editor, `appState.markdownContent` changes, triggering `MarkdownPreviewView`'s `.task(id: appState.markdownContent)` (line 24 of MarkdownPreviewView.swift). This re-renders all blocks via `MarkdownRenderer.render()` (line 31-34). The changed Mermaid code produces a new `MarkdownBlock.mermaidBlock(code:)` with different content. SwiftUI creates a new `MermaidBlockView` with the new code. Since the new code has a different hash, `MermaidImageStore.get()` returns nil, and the full render pipeline executes. `.task(id: code)` correctly fires because the `code` value is new. Side-by-side mode uses the same `MarkdownPreviewView` (confirmed at `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/SplitEditorView.swift:11`).
- Field Notes: N/A
- Issues: None.

### REQ-005: No Scroll Re-render Issues in Side-by-Side Mode
**AC-5a**: Scrolling through Mermaid-containing content in side-by-side mode does not trigger visible re-render loops or jank.
- Status: VERIFIED (code-level) / MANUAL_REQUIRED (visual)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/SplitEditorView.swift:11` reuses `MarkdownPreviewView()`
- Evidence: `SplitEditorView` uses the exact same `MarkdownPreviewView()` component for its preview pane. The same `LazyVStack`, same `MermaidBlockView` (with cache-aware init), and same `.task(id: code)` behavior apply. The fix is structural and applies uniformly to both view modes.
- Field Notes: N/A
- Issues: Visual confirmation needed to fully verify, but code analysis shows identical rendering path.

### REQ-006: Non-Mermaid Block Stability During Scroll
**AC-6a**: Images that have already loaded do not show a loading placeholder when scrolled back into view.
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/ImageBlockView.swift:27` (`.task(id: source)`) and lines 84-85 (early-return guard)
- Evidence: `ImageBlockView` uses `.task(id: source)` (line 27) instead of plain `.task`, which prevents re-firing when the parent body re-evaluates without content change. The `loadImage()` method has an early-return guard at line 85: `guard loadedImage == nil, !loadError else { return }`. However, there is NO external image cache (no `ImageStore` singleton). When LazyVStack recycles the view (destroys and recreates it), `@State` is reset, `loadedImage` becomes nil, and the image must reload from disk/network. The early-return guard only helps when the @State is preserved (which is not guaranteed in LazyVStack for nested child views). The design.md acknowledges this gap (section 3.3) and marks a full `ImageStore` as an "optional enhancement."
- Field Notes: N/A
- Issues: Without an `ImageStore` cache, images in recycled views will show a loading placeholder on scroll-back when @State is destroyed by LazyVStack. This is a known design trade-off documented in design.md. The `.task(id:)` + early-return pattern prevents the re-render *cycle* but does not prevent the loading flicker on scroll-back.

**AC-6b**: Code blocks do not visibly re-highlight when scrolled back into view.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift:47-73`
- Evidence: `CodeBlockView` uses a synchronous computed property `highlightedCode` (line 47) that runs the Splash highlighter during body evaluation. There is no `.task`, no `.onAppear`, no async work, and no loading state. When the view is recycled by LazyVStack, the new instance re-computes `highlightedCode` synchronously in the body -- the highlighted text appears immediately with no flicker or visible re-highlight phase. The Splash `SyntaxHighlighter` is lightweight (string manipulation only, no JS or async). This is inherently stable during scroll recycling.
- Field Notes: N/A
- Issues: None. Code blocks are inherently scroll-safe because highlighting is synchronous.

## Implementation Gap Analysis

### Missing Implementations
- **TD1**: Documentation for MermaidImageStore in `.rp1/context/modules.md` -- not yet written (task unchecked in tasks.md)
- **TD2**: Update Mermaid Diagrams pipeline description in `.rp1/context/architecture.md` -- not yet written (task unchecked in tasks.md)
- **TD3**: Update Anti-Patterns section in `.rp1/context/patterns.md` with cache-aware init pattern -- not yet written (task unchecked in tasks.md)

### Partial Implementations
- **AC-6a (ImageBlockView scroll-back)**: The `.task(id:)` + early-return guard pattern is implemented, but no `ImageStore` singleton exists for synchronous cache-aware init. When LazyVStack destroys @State for a nested ImageBlockView, images will reload on scroll-back. The design explicitly marks this as an optional enhancement with lower severity (images load faster than Mermaid). This is a known, documented trade-off.

### Implementation Issues
- None. All code implementations match the design specification precisely with no deviations.

## Code Quality Assessment

**Overall: HIGH**

The implementation demonstrates strong engineering discipline:

1. **Pattern consistency**: `MermaidImageStore` follows the exact same LRU cache pattern as `MermaidCache` (same structure, same DJB2 hashing, same capacity). This reduces cognitive load and makes the codebase predictable.

2. **Separation of concerns**: The `@MainActor` `MermaidImageStore` singleton correctly separates the view-layer cache (NSImage, MainActor-isolated) from the render-layer cache (SVG string, actor-isolated in MermaidRenderer). This respects Swift concurrency isolation boundaries.

3. **Defensive coding**: The `renderDiagram()` guard clause (`guard renderedImage == nil, errorMessage == nil else { return }`) is a belt-and-suspenders approach -- the cache-aware init should already have populated `renderedImage`, but the guard ensures safety even if SwiftUI behaves unexpectedly.

4. **Stable identity**: The `ListItem` ID migration from `UUID()` to content-derived hashing (`"li-\(blocks.map(\.id).joined(separator: "-"))"`) is clean and matches the existing pattern used by all other `MarkdownBlock` cases.

5. **Test coverage**: 9 unit tests for `MermaidImageStore` covering all LRU behaviors (miss, hit, identity, eviction, promotion, overwrite, removeAll, count). 2 unit tests for `ListItem` ID stability. All 157 tests pass with 0 failures.

6. **Cache invalidation**: Properly wired at both the file-load level (`AppState.loadFile(at:)` line 82) and theme-change level (`MarkdownPreviewView.onChange(of: appState.theme)` line 37). Per-block invalidation is automatic via `.task(id: code)`.

7. **Documentation**: All code files have clear doc comments explaining purpose and design rationale.

**Minor observations**:
- The `MermaidImageStore.init` is `internal` (not `private`), which allows test construction with custom capacity. This is correct and intentional.
- The `mermaidStableHash` function is a module-level function in `MermaidCache.swift`, shared between `MermaidCache` and `MermaidImageStore`. This avoids duplication.

## Recommendations

1. **Complete documentation tasks (TD1, TD2, TD3)**: Update `.rp1/context/modules.md`, `architecture.md`, and `patterns.md` to document MermaidImageStore and the cache-aware init pattern. These are tracked as incomplete in tasks.md.

2. **Perform manual scroll verification**: Open a Markdown file with 5+ Mermaid diagrams and verify AC-1a, AC-1b, AC-1c, and AC-5a through physical testing. Monitor Activity Monitor during scroll to confirm CPU returns to idle (NFR-2).

3. **Consider ImageStore for full AC-6a compliance**: If image loading flicker on scroll-back is observed to be annoying in practice, implement an `ImageStore` singleton following the exact same pattern as `MermaidImageStore`. The design already documents this approach in section 3.3. Priority is low since images load much faster than Mermaid diagrams.

4. **Add field-notes.md**: Consider creating a field-notes.md documenting the AC-6a trade-off decision (ImageBlockView uses `.task(id:)` + guard but no external cache) for future reference.

## Verification Evidence

### MermaidImageStore -- New file implementing NSImage LRU cache
**File**: `/Users/jud/Projects/mkdn/mkdn/Core/Mermaid/MermaidImageStore.swift`
- `@MainActor final class` with `static let shared` singleton (lines 12-14)
- `get(_ code: String) -> NSImage?` synchronous lookup with LRU promotion (lines 26-33)
- `store(_ code: String, image: NSImage)` with LRU eviction at capacity 50 (lines 37-51)
- `removeAll()` for invalidation (lines 54-57)
- Uses `mermaidStableHash` (DJB2) for cache keys (lines 27, 38)

### MermaidBlockView -- Cache-aware init and .task(id:)
**File**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MermaidBlockView.swift`
- `@MainActor init(code:)` with synchronous `MermaidImageStore.shared.get(code)` (line 26)
- `@State` initialized from cache: `_renderedImage = State(initialValue: cached)` (line 27)
- `_isLoading = State(initialValue: cached == nil)` (line 29)
- `.task(id: code)` instead of `.task` (line 42)
- `renderDiagram()` early-return guard: `guard renderedImage == nil, errorMessage == nil else { return }` (line 153)
- Stores rendered image: `MermaidImageStore.shared.store(code, image: image)` (line 161)
- Zoom/activation behavior unchanged (lines 49-117)

### ImageBlockView -- .task(id:) and early-return guard
**File**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/ImageBlockView.swift`
- `.task(id: source)` instead of `.task` (line 27)
- `loadImage()` early-return guard: `guard loadedImage == nil, !loadError else { return }` (line 85)
- No external cache (design trade-off, documented as optional enhancement)

### MarkdownBlock ListItem -- Content-derived stable ID
**File**: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownBlock.swift`
- `ListItem.id` is computed property: `"li-\(blocks.map(\.id).joined(separator: "-"))"` (lines 62-64)
- No longer uses `UUID()` -- stable across consecutive parse passes
- DJB2 `stableHash` function at lines 69-74 is deterministic across launches

### Cache invalidation wiring
**File**: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`
- `MermaidImageStore.shared.removeAll()` in `loadFile(at:)` (line 82)

**File**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`
- `MermaidImageStore.shared.removeAll()` in `.onChange(of: appState.theme)` (line 37)

### Test coverage
**File**: `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/MermaidImageStoreTests.swift`
- 9 tests: cacheMiss, basicStoreAndGet, cacheHitReturnsSameInstance, differentCodeMisses, overwriteExistingEntry, lruEviction, accessPromotesEntry, removeAllClearsCache, countTracksEntries

**File**: `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/MarkdownBlockTests.swift`
- 2 tests: listItemIdStability, listItemIdDiffers

**Test results**: 157 passed, 0 failed
