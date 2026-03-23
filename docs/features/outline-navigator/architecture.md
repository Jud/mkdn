# Architecture: Document Outline Navigator

**Status:** Approved

## Revision History

| Date | Change | Reason |
|------|--------|--------|
| 2026-03-21 | Added comprehension-mode consideration to overview and testing strategy | User feedback: outline serves document structure comprehension, not just navigation |

## Overview

The Document Outline Navigator adds a unified breadcrumb/outline component to the Markdown preview view. It serves two primary purposes: navigation (jumping to a specific heading) and comprehension (understanding the overall shape and organization of a document at a glance). It consists of three logical layers: (1) a heading tree model extracted from already-parsed `[IndexedBlock]` data, (2) a scroll-spy mechanism that tracks the user's position in the document structure, and (3) a SwiftUI view that renders as either a thin breadcrumb bar or an expanded outline HUD, controlled by an `@Observable` state class.

The design follows the established overlay pattern used by `FindBarView`/`FindState`: a state class manages visibility and selection, the view lives in the `ContentView` ZStack, and the keyboard shortcut is registered in `MkdnCommands` via `@FocusedValue`[^find-bar-pattern].

> **Cross-refs:** If this section changes, MUST also update:
> - prd.md § "Problem Statement" (motivation alignment)

## System Context

The outline navigator sits in the Feature layer, alongside the existing Viewer module. It reads from the Core/Markdown rendering pipeline (the `[IndexedBlock]` array already produced by `MarkdownRenderer`) and uses the UI/Theme system for styling and animation.

```
App Layer
├── MkdnCommands          ← registers Cmd+J shortcut
├── DocumentWindow         ← creates OutlineState, injects via .environment()
├── ContentView            ← hosts OutlineNavigatorView in ZStack
│
Feature Layer
├── Viewer/
│   ├── MarkdownPreviewView  ← provides renderedBlocks, hosts scroll-spy
│   ├── SelectableTextView   ← Coordinator observes scroll for spy
│   └── FindBarView          ← reference implementation
├── Outline/                 ← NEW
│   ├── ViewModels/OutlineState.swift
│   ├── Views/OutlineNavigatorView.swift
│   └── Views/OutlineBreadcrumbBar.swift
│
Core Layer
├── Markdown/
│   ├── HeadingTreeBuilder.swift  ← NEW: extracts heading tree from [IndexedBlock]
│   └── HeadingNode.swift         ← NEW: tree node type
│
UI/Theme
├── AnimationConstants     ← existing primitives (springSettle, fadeIn, etc.)
└── MotionPreference       ← Reduce Motion resolution
```

## Component Design -- New Components

### 1. HeadingNode (`mkdn/Core/Markdown/HeadingNode.swift`)

**Responsibility:** Tree node representing a heading in the document outline.

**Key types:**
```swift
public struct HeadingNode: Identifiable, Sendable {
    public let id: Int                 // Same as blockIndex; unique per heading, semantically meaningful
    public let title: String           // Plain text of the heading
    public let level: Int              // 1-6
    public let blockIndex: Int         // IndexedBlock.index for scroll targeting
    public var children: [HeadingNode] // Sub-headings
}
```

**Design notes:**
- Uses `blockIndex` as `id` -- avoids UUID allocation for a frequently-rebuilt transient structure and makes SwiftUI diffing more efficient (same headings at same positions are recognized as identical).
- Uses plain `String` title (stripped from `AttributedString`) for display and filtering. The attributed version is not needed in the outline -- we just need the text.
- `blockIndex` maps directly to `IndexedBlock.index`, which is the sequential position in the rendered block array. This is the key used by `BlockScrollTarget` and can be used to calculate the scroll position via the text layout manager[^existing-heading-infrastructure].
- `Sendable` because it's a pure value type.

### 2. HeadingTreeBuilder (`mkdn/Core/Markdown/HeadingTreeBuilder.swift`)

**Responsibility:** Stateless utility that extracts a heading tree from `[IndexedBlock]`.

**Key types:**
```swift
public enum HeadingTreeBuilder {
    public static func buildTree(from blocks: [IndexedBlock]) -> [HeadingNode]
}
```

**Design notes:**
- Follows the project's stateless enum pattern (like `MarkdownRenderer`, `SyntaxHighlightEngine`)[^existing-heading-infrastructure].
- Algorithm: iterate blocks, filter for `.heading` cases, build tree by level nesting. A heading at level N is a child of the most recent heading at level N-1. Top-level headings (or headings with no parent at a lower level) become root nodes.
- Returns `[HeadingNode]` (array of roots) rather than a single root, because documents may have multiple h1s or start with h2.
- Also provides a `breadcrumbPath(to blockIndex: Int, in tree: [HeadingNode]) -> [HeadingNode]` method that returns the ancestor chain for a given block index.

### 3. OutlineState (`mkdn/Features/Outline/ViewModels/OutlineState.swift`)

**Responsibility:** Per-window `@Observable` state managing the outline navigator's lifecycle.

**Key types:**
```swift
@MainActor
@Observable
public final class OutlineState {
    // Heading data
    public private(set) var headingTree: [HeadingNode] = []
    public private(set) var flatHeadings: [HeadingNode] = []  // pre-flattened for HUD list

    // Scroll-spy output
    public private(set) var currentHeadingIndex: Int?  // blockIndex of current heading
    public private(set) var breadcrumbPath: [HeadingNode] = []

    // HUD state
    public var isHUDVisible = false
    public var filterQuery = ""
    public var selectedIndex: Int = 0  // index in filtered list

    // Breadcrumb visibility
    public private(set) var isBreadcrumbVisible = false

    // Methods
    public func updateHeadings(from blocks: [IndexedBlock])
    public func updateScrollPosition(currentBlockIndex: Int)
    public func toggleHUD()
    public func showHUD()
    public func dismissHUD()
    public func selectAndNavigate() -> Int?  // returns blockIndex to scroll to
    public func moveSelectionUp()
    public func moveSelectionDown()

    public var filteredHeadings: [HeadingNode]  // computed, fuzzy-filtered
}
```

**Design notes:**
- Follows `FindState` pattern: `@MainActor @Observable`, created as `@State` in `DocumentWindow`, injected via `.environment()`.
- `flatHeadings` is a pre-flattened depth-first traversal of the tree, used for the HUD list and keyboard navigation. Avoids recomputing on every render.
- `filteredHeadings` is a computed property that applies fzf-style fuzzy filtering to `flatHeadings` based on `filterQuery`. Characters in the query match in order but not necessarily adjacent (e.g., "morch" matches "Migration Orchestrator"). A simple scoring algorithm prioritizes consecutive character matches and word-boundary matches.
- `toggleHUD()` calls `showHUD()` if the HUD is hidden, `dismissHUD()` if visible. This is the entry point for Cmd+J.
- `showHUD()` sets `selectedIndex` to the index of `currentHeadingIndex` in the filtered list, ensuring the HUD auto-scrolls to the current heading on open.
- Breadcrumb visibility is driven by scroll-spy: `isBreadcrumbVisible` becomes true when the viewport scrolls past the first heading's position.

### 4. OutlineNavigatorView (`mkdn/Features/Outline/Views/OutlineNavigatorView.swift`)

**Responsibility:** SwiftUI view rendering either the breadcrumb bar or the expanded HUD, depending on `OutlineState`.

**Design notes:**
- Single view with two visual states (not two separate views). Uses conditional content + `matchedGeometryEffect` or explicit size animation to transition between breadcrumb and HUD.
- Positioned via `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` within the `ContentView` ZStack, similar to `FindBarView`.
- Uses `.ultraThinMaterial` background.
- Keyboard handling via `.onKeyPress()` for arrow keys, Enter, Escape, and character input.
- The breadcrumb bar portion may be extracted as a sub-view (`OutlineBreadcrumbBar`) for clarity.

### 5. OutlineBreadcrumbBar (`mkdn/Features/Outline/Views/OutlineBreadcrumbBar.swift`)

**Responsibility:** The collapsed breadcrumb bar subview showing the heading path.

**Design notes:**
- Displays `breadcrumbPath` as text segments separated by chevron separators.
- The entire breadcrumb bar is a single `Button` that opens the outline HUD on click. Individual segments are not independently clickable.
- Fades in/out based on `isBreadcrumbVisible`.

> **Cross-refs:** If this section changes, MUST also update:
> - prd.md § "Functional Requirements" (component responsibilities map to FRs)
> - prd.md § "User Experience" (visual design described there)

## Component Design -- Modified Components

### 1. ContentView (`mkdn/App/ContentView.swift`)

**Change:** Add `OutlineNavigatorView()` to the root ZStack, alongside `FindBarView()`.

```swift
// In ContentView.body ZStack:
OutlineNavigatorView()
    .allowsHitTesting(outlineState.isHUDVisible || outlineState.isBreadcrumbVisible)
    .accessibilityHidden(!outlineState.isBreadcrumbVisible && !outlineState.isHUDVisible)
```

### 2. DocumentWindow (`mkdn/App/DocumentWindow.swift`)

**Change:** Create `OutlineState` as `@State`, inject via `.environment()`, publish via `.focusedSceneValue()`.

```swift
@State private var outlineState = OutlineState()
// ...
.environment(outlineState)
.focusedSceneValue(\.outlineState, outlineState)
```

### 3. MkdnCommands (`mkdn/App/MkdnCommands.swift`)

**Change:** Add Cmd+J menu item in the View section that toggles the outline HUD.

```swift
@FocusedValue(\.outlineState) private var outlineState

Button("Document Outline") {
    withAnimation(motionAnimation(.springSettle)) {
        outlineState?.toggleHUD()
    }
}
.keyboardShortcut("j", modifiers: .command)
.disabled(outlineState?.headingTree.isEmpty ?? true)
```

### 4. FocusedOutlineStateKey (`mkdn/App/FocusedOutlineStateKey.swift`) -- NEW

**Change:** New `FocusedValueKey` for `OutlineState`, following the pattern of `FocusedDocumentStateKey`.

### 5. MarkdownPreviewView (`mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`)

**Change:** Feed rendered blocks to `OutlineState` when they change, so the heading tree stays current.

```swift
@Environment(OutlineState.self) private var outlineState

// In .task(id: documentState.markdownContent) or renderAndBuild():
outlineState.updateHeadings(from: newBlocks)
```

### 6. SelectableTextView+Coordinator (`mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift`)

**Change:** Add scroll position observation to feed scroll-spy data to `OutlineState`. The Coordinator subscribes to `NSView.boundsDidChangeNotification` on the scroll view's clip view and reports the visible block index to `OutlineState`[^scroll-mechanics].

This is the most delicate modification. The Coordinator needs:
1. A reference to `OutlineState` (passed during `makeNSView` or `updateNSView`)
2. An `NSObjectProtocol` observation token for the bounds change notification
3. Logic to map the scroll position (y offset) to the current heading block index using the text layout manager[^a1-evidence]

For scroll-to-heading navigation (when the user selects a heading in the HUD), use `scrollView.contentView.scroll(to:)` + `reflectScrolledClipView()` with the heading's y-coordinate from the layout fragment, positioning the heading at the viewport top[^a2-evidence].

> **Cross-refs:** If this section changes, MUST also update:
> - prd.md § "Functional Requirements" FR-9 through FR-11 (scroll-spy requirements)
> - architecture.md § "Flow Diagrams" Flow 2 (scroll-spy flow depends on Coordinator implementation)

## Data Model

No database tables or persistent storage. All state is transient and per-window:

| Field | Type | Lifecycle |
|-------|------|-----------|
| `headingTree` | `[HeadingNode]` | Rebuilt on each render |
| `flatHeadings` | `[HeadingNode]` | Derived from tree |
| `currentHeadingIndex` | `Int?` | Updated on scroll |
| `breadcrumbPath` | `[HeadingNode]` | Derived from current heading + tree |
| `isHUDVisible` | `Bool` | User-toggled |
| `filterQuery` | `String` | User input |
| `selectedIndex` | `Int` | Keyboard navigation |

## API Changes

No external API changes. All new types are `internal` to `mkdnLib` (they serve the macOS viewer only, not the platform/iOS layer). The only new public type would be `HeadingNode` if we want external consumers to access the heading tree, but that is not needed initially.

One new menu item: **View > Document Outline** (Cmd+J).

## Flow Diagrams

### Flow 1: Document Load → Heading Tree

1. User opens a Markdown file
2. `MarkdownPreviewView.task(id:)` triggers render
3. `MarkdownRenderer.render()` produces `[IndexedBlock]`
4. `MarkdownPreviewView` calls `outlineState.updateHeadings(from: newBlocks)`
5. `OutlineState` calls `HeadingTreeBuilder.buildTree(from:)` → stores `headingTree` and `flatHeadings`
6. Breadcrumb bar remains invisible (user hasn't scrolled yet)

### Flow 2: Scroll → Breadcrumb Update

1. User scrolls the document
2. `NSView.boundsDidChangeNotification` fires on the clip view
3. Coordinator reads `contentView.bounds.origin.y`
4. Coordinator maps y-position to the nearest heading block index via text layout manager
5. Coordinator calls `outlineState.updateScrollPosition(currentBlockIndex:)`
6. `OutlineState` computes `breadcrumbPath` from `headingTree`
7. `OutlineState` sets `isBreadcrumbVisible = true` if past first heading
8. `OutlineBreadcrumbBar` updates to show the new path

### Flow 3: Cmd+J → Navigate → Dismiss

1. User presses Cmd+J
2. `MkdnCommands` calls `outlineState.toggleHUD()`, which resolves to `showHUD()`
3. `OutlineNavigatorView` animates from breadcrumb to expanded HUD (spring)
4. Filter text field receives focus via `@FocusState`
5. User types "migr" → `filterQuery` updates → `filteredHeadings` narrows
6. User presses Down arrow → `selectedIndex` advances
7. User presses Enter → `outlineState.selectAndNavigate()` returns `blockIndex`
8. View scrolls to the heading at that block index
9. HUD collapses back to breadcrumb (reverse spring animation)

### Flow 4: Breadcrumb Click → HUD Open

1. User clicks anywhere on the breadcrumb bar
2. `OutlineBreadcrumbBar` calls `outlineState.showHUD()` with spring animation
3. HUD expands from the breadcrumb, auto-scrolled to the current heading
4. (Same as Flow 3 from step 4 onward)

## Error Handling

| Failure Mode | Detection | Recovery |
|-------------|-----------|----------|
| Document has no headings | `headingTree.isEmpty` after `updateHeadings` | Breadcrumb never appears; Cmd+J menu item is disabled (greyed out) |
| Scroll-spy returns no heading | First scroll before any heading | `currentHeadingIndex` stays `nil`; breadcrumb stays hidden |
| Block index out of range (stale data) | `blockIndex >= blocks.count` | Clamp to valid range or skip navigation |
| Text layout not ready during scroll-spy | Layout manager returns nil rect | Skip update, wait for next scroll event |

## Security Considerations

No security surface. The feature reads from already-parsed in-memory data (heading text from `MarkdownBlock`) and performs no I/O, network access, or user input interpretation beyond fuzzy string matching.

## Testing Strategy

> **Cross-refs:** If this section changes, MUST also update:
> - prd.md § "User Stories" (test scenarios should cover these stories)
> - prd.md § "Success Metrics" (tests validate these metrics)

### Unit Tests (`mkdnTests/Unit/Core/HeadingTreeBuilderTests.swift`)

Test `HeadingTreeBuilder.buildTree(from:)`:
- Empty document → empty tree
- Flat headings (all same level) → flat list of roots
- Nested headings (h1 > h2 > h3) → proper tree nesting
- Skip levels (h1 > h3, no h2) → h3 becomes child of h1
- Multiple h1s → multiple root nodes
- Mixed content (headings interspersed with paragraphs, code blocks) → only headings extracted
- Breadcrumb path computation: given a block index, returns correct ancestor chain

### Unit Tests (`mkdnTests/Unit/Features/OutlineStateTests.swift`)

Test `OutlineState`:
- `updateHeadings` populates tree and flat list
- `updateScrollPosition` sets correct breadcrumb path
- `isBreadcrumbVisible` transitions based on scroll position
- `toggleHUD` shows when hidden, dismisses when visible
- `showHUD` / `dismissHUD` control state directly
- `filterQuery` produces correct `filteredHeadings` (fzf-style fuzzy match: "morch" matches "Migration Orchestrator")
- `showHUD` auto-selects the current heading in the filtered list
- `moveSelectionUp` / `moveSelectionDown` wrap correctly
- `selectAndNavigate` returns correct block index

### Visual Verification

Per project convention, visual verification via test harness after implementation:
1. Load a long document with multiple heading levels
2. Scroll to verify breadcrumb appears/disappears
3. Cmd+J to verify HUD appearance and heading list
4. Verify the heading tree is readable as a structural overview (comprehension mode): indentation clearly communicates hierarchy, heading levels are visually distinct, and the overall document shape is apparent without interaction
5. Verify in both Solarized Light and Solarized Dark themes
6. Verify with Reduce Motion enabled

## Implementation Plan

> **Cross-refs:** If this section changes, MUST also update:
> - architecture.md § "Estimated Complexity" (LOC estimates must stay in sync)
> - architecture.md § "Component Design" (phases reference these components)

### Phase 1: Core Data Model (independently shippable)
- `HeadingNode` struct
- `HeadingTreeBuilder` with tree construction and breadcrumb path
- Unit tests for tree builder
- **Estimated:** ~100 LOC production, ~150 LOC tests

### Phase 2: State Management (independently testable)
- `OutlineState` class
- `FocusedOutlineStateKey`
- Unit tests for state
- **Estimated:** ~150 LOC production, ~200 LOC tests

### Phase 3: Breadcrumb Bar (independently visible)
- `OutlineBreadcrumbBar` view
- Integration into `ContentView` and `DocumentWindow`
- Scroll-spy wiring in `SelectableTextView+Coordinator`
- Feed heading data from `MarkdownPreviewView`
- **Estimated:** ~200 LOC production

### Phase 4: Outline HUD (feature complete)
- `OutlineNavigatorView` with HUD state
- Keyboard navigation and fuzzy filtering
- Breadcrumb-to-HUD animation
- Cmd+J registration in `MkdnCommands`
- **Estimated:** ~250 LOC production

### Phase 5: Polish & Visual Verification
- Theme verification (both themes)
- Reduce Motion verification
- Edge cases (empty document, single heading, very long heading text)
- **Estimated:** ~50 LOC adjustments

## Estimated Complexity

> **Cross-refs:** If this section changes, MUST also update:
> - architecture.md § "Implementation Plan" (LOC estimates must stay in sync)

| Component | Estimated LOC | Affected Modules |
|-----------|--------------|-----------------|
| HeadingNode | ~30 | Core/Markdown |
| HeadingTreeBuilder | ~70 | Core/Markdown |
| OutlineState | ~150 | Features/Outline |
| OutlineBreadcrumbBar | ~80 | Features/Outline |
| OutlineNavigatorView | ~170 | Features/Outline |
| FocusedOutlineStateKey | ~15 | App |
| Modified: ContentView | ~5 | App |
| Modified: DocumentWindow | ~10 | App |
| Modified: MkdnCommands | ~15 | App |
| Modified: MarkdownPreviewView | ~5 | Features/Viewer |
| Modified: SelectableTextView+Coordinator | ~50 | Features/Viewer |
| Tests | ~350 | mkdnTests |
| **Total** | **~950** | |

[^find-bar-pattern]: [Find Bar Overlay Pattern](research/find-bar-overlay-pattern.md)
[^existing-heading-infrastructure]: [Existing Heading Infrastructure](research/existing-heading-infrastructure.md)
[^scroll-mechanics]: [Scroll Mechanics](research/scroll-mechanics.md)
[^a1-evidence]: [A1: NSTextLayoutManager Y-Coordinate Mapping](research/a1-layout-manager-y-coordinates.md)
[^a2-evidence]: [A2: Programmatic Scrolling to Heading Positions](research/a2-programmatic-scroll-to-heading.md)
