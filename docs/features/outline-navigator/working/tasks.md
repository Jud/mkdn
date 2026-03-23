# Build Tasks: Document Outline Navigator

**Status:** Complete
**Total Tasks:** 12
**Completed:** 12

## Task Graph

The feature builds bottom-up: data model first, then state management, then UI, then integration wiring.

Batch 1 (parallel): T1, T2
- T1 builds the heading tree data model and extraction logic (Core layer, no dependencies)
- T2 builds the OutlineState class (Feature layer, uses HeadingNode type but can be built with a stub/inline definition and connected later -- however, since HeadingNode is a simple struct that T1 will produce, and T2 needs it, T2 depends on T1)

**Revised:** T1 and T2 are sequential (T2 depends on T1).

Batch 2 (parallel): T3, T4
- T3 creates the FocusedOutlineStateKey and wires OutlineState into DocumentWindow + ContentView (App layer plumbing)
- T4 builds the breadcrumb bar view (UI, needs OutlineState from T2 but not the integration wiring)

**Revised:** T3 depends on T2. T4 depends on T2.

Batch 3 (sequential): T5
- T5 builds the Outline HUD view with keyboard navigation, fuzzy filter, and breadcrumb-to-HUD animation. Depends on T2 (state), T3 (environment wiring), T4 (breadcrumb subview).

Batch 4 (sequential): T6
- T6 wires scroll-spy into SelectableTextView+Coordinator and feeds heading data from MarkdownPreviewView. Depends on T1 (heading tree), T2 (OutlineState), T3 (environment plumbing).

Batch 5 (sequential): T7
- T7 registers Cmd+J in MkdnCommands, adds scroll-to-heading navigation, and performs visual verification. Depends on all prior tasks.

```
Batch 1: T1
Batch 2: T2 (depends on T1)
Batch 3 (parallel): T3, T4 (both depend on T2)
Batch 4: T5 (depends on T3, T4)
Batch 5: T6 (depends on T1, T2, T3)
Batch 6: T7 (depends on T5, T6)
```

**Rework triggered by manual code review. Affected: T8, T9, T10, T11, T12.**

Fix tasks for issues found during review of the completed T1-T7 build:

```
Batch 7 (parallel): T8, T9, T10
  - T8: cache filtered headings in OutlineState (minor, T2 fix)
  - T9: add max width / truncation to breadcrumb bar (minor, T4 fix)
  - T10: cache heading y-positions in scroll-spy (MAJOR, T6 fix)
Batch 8 (sequential): T11
  - T11: rebuild OutlineNavigatorView as single morphing component (MAJOR, T5 fix)
  - Depends on T8 (uses cached filteredHeadings), T9 (breadcrumb changes)
Batch 9 (sequential): T12
  - T12: visual verification of all fixes
  - Depends on T10, T11
```

## Tasks

### T1. HeadingNode and HeadingTreeBuilder — Core Data Model
**Status:** done
**Depends on:** —
**Files:** `mkdn/Core/Markdown/HeadingNode.swift` (new), `mkdn/Core/Markdown/HeadingTreeBuilder.swift` (new), `mkdnTests/Unit/Core/HeadingTreeBuilderTests.swift` (new)
**Review:** reviews/T1-review-1.md
**Spec:**

Create the heading tree data model and extraction logic.

**HeadingNode** (`mkdn/Core/Markdown/HeadingNode.swift`):
```swift
public struct HeadingNode: Identifiable, Sendable {
    public let id: Int          // Same as blockIndex
    public let title: String    // Plain text (from AttributedString.characters)
    public let level: Int       // 1-6
    public let blockIndex: Int  // IndexedBlock.index for scroll targeting
    public var children: [HeadingNode]
}
```
- `id` uses `blockIndex` (no UUID allocation).
- `Sendable` because it is a pure value type.
- Provide an explicit `public init`.

**HeadingTreeBuilder** (`mkdn/Core/Markdown/HeadingTreeBuilder.swift`):
```swift
public enum HeadingTreeBuilder {
    public static func buildTree(from blocks: [IndexedBlock]) -> [HeadingNode]
    public static func flattenTree(_ tree: [HeadingNode]) -> [HeadingNode]
    public static func breadcrumbPath(to blockIndex: Int, in tree: [HeadingNode]) -> [HeadingNode]
}
```
- Stateless enum (matches `MarkdownRenderer`, `SyntaxHighlightEngine` pattern).
- `buildTree`: iterate `blocks`, filter for `.heading(level:text:)` cases, build tree by level nesting. A heading at level N becomes a child of the most recent heading at level < N. If no such parent exists, it becomes a root node. Extract title via `String(text.characters)`.
- `flattenTree`: depth-first pre-order traversal returning a flat `[HeadingNode]`.
- `breadcrumbPath`: given a `blockIndex`, return the ancestor chain from root to the heading containing that blockIndex (or the last heading at or before that blockIndex). Walk the tree: for each level, include the last heading whose `blockIndex <= targetBlockIndex`.

**Algorithm for `buildTree`:**
```
var roots: [HeadingNode] = []
var stack: [(level: Int, nodeIndex: Int, parentPath: [Int])] = []
for each IndexedBlock where block is .heading(level, text):
    let node = HeadingNode(...)
    pop stack entries with level >= current level
    if stack is empty:
        append node to roots
    else:
        append node as child of the node at stack.top
    push current node onto stack
```

**Tests** (`mkdnTests/Unit/Core/HeadingTreeBuilderTests.swift`):
Use `@Suite("HeadingTreeBuilder")` and `@Test`. Create helper to build `[IndexedBlock]` from `(level, title)` pairs.

Test cases for `buildTree`:
1. Empty input → empty output
2. Single heading → single root node
3. Flat headings (all h2) → flat list of roots
4. Nested h1 > h2 > h3 → proper tree (h2 is child of h1, h3 is child of h2)
5. Skip levels: h1 > h3 (no h2) → h3 becomes child of h1
6. Multiple h1s → multiple root nodes
7. Mixed content: headings interspersed with paragraphs and code blocks → only headings extracted, indices preserved
8. Complex document: h1, h2, h2, h3, h1, h2 → two root h1s, first has two h2 children (second h2 has one h3 child), second h1 has one h2 child

Test cases for `flattenTree`:
1. Empty → empty
2. Nested tree → depth-first pre-order

Test cases for `breadcrumbPath`:
1. blockIndex matches a root heading → path of length 1
2. blockIndex matches a nested h3 → path [h1, h2, h3]
3. blockIndex is between two headings → path to the preceding heading
4. blockIndex before any heading → empty path
5. blockIndex matches a heading with skipped levels → correct chain

**Acceptance criteria:**
- `swift test --filter HeadingTreeBuilder` passes all tests
- `HeadingNode` conforms to `Identifiable` and `Sendable`
- `HeadingTreeBuilder` is an uninhabitable enum with static methods
- `#if os(macOS)` guard is NOT needed — these are pure data types usable cross-platform
- SwiftLint and SwiftFormat pass

---

### T2. OutlineState — State Management
**Status:** done
**Depends on:** T1
**Files:** `mkdn/Features/Outline/ViewModels/OutlineState.swift` (new), `mkdnTests/Unit/Features/OutlineStateTests.swift` (new)
**Review:** reviews/T2-review-1.md
**Spec:**

Create the per-window observable state class for the outline navigator.

**OutlineState** (`mkdn/Features/Outline/ViewModels/OutlineState.swift`):
```swift
#if os(macOS)
@MainActor
@Observable
public final class OutlineState {
    // Heading data
    public private(set) var headingTree: [HeadingNode] = []
    public private(set) var flatHeadings: [HeadingNode] = []

    // Scroll-spy output
    public private(set) var currentHeadingIndex: Int?   // blockIndex of current heading
    public private(set) var breadcrumbPath: [HeadingNode] = []

    // HUD state
    public var isHUDVisible = false
    public var filterQuery = ""
    public var selectedIndex: Int = 0   // index in filteredHeadings

    // Breadcrumb visibility
    public private(set) var isBreadcrumbVisible = false

    public init() {}

    // MARK: - Heading Updates
    public func updateHeadings(from blocks: [IndexedBlock])
    // Calls HeadingTreeBuilder.buildTree, stores headingTree and flatHeadings.
    // If headingTree is empty, ensures breadcrumb/HUD are hidden.

    // MARK: - Scroll-Spy
    public func updateScrollPosition(currentBlockIndex: Int)
    // Sets currentHeadingIndex to the last heading in flatHeadings whose
    // blockIndex <= currentBlockIndex.
    // Updates breadcrumbPath via HeadingTreeBuilder.breadcrumbPath().
    // Sets isBreadcrumbVisible = true if currentHeadingIndex != nil
    // (i.e., viewport has scrolled past the first heading).
    // If currentBlockIndex < first heading's blockIndex, sets
    // isBreadcrumbVisible = false and currentHeadingIndex = nil.

    // MARK: - HUD Lifecycle
    public func toggleHUD()
    // Calls showHUD() if !isHUDVisible, else dismissHUD().

    public func showHUD()
    // Sets isHUDVisible = true, filterQuery = "".
    // Sets selectedIndex to the index of currentHeadingIndex in filteredHeadings.
    // If currentHeadingIndex is nil, selectedIndex = 0.

    public func dismissHUD()
    // Sets isHUDVisible = false, filterQuery = "".

    // MARK: - Navigation
    public func selectAndNavigate() -> Int?
    // Returns the blockIndex of the heading at selectedIndex in filteredHeadings.
    // Calls dismissHUD() after. Returns nil if filteredHeadings is empty.

    public func moveSelectionUp()
    // Decrements selectedIndex, wrapping from 0 to filteredHeadings.count - 1.
    // No-op if filteredHeadings is empty.

    public func moveSelectionDown()
    // Increments selectedIndex, wrapping from last to 0.
    // No-op if filteredHeadings is empty.

    // MARK: - Filtering
    public var filteredHeadings: [HeadingNode]
    // Computed property. If filterQuery is empty, returns flatHeadings.
    // Otherwise, applies fuzzy matching: each character in filterQuery must
    // appear in the heading title in order (case-insensitive), but not
    // necessarily adjacent. Example: "morch" matches "Migration Orchestrator".
    // Simple scoring: prefer consecutive matches and word-boundary matches.
    // Sort by score descending.
}
#endif
```

**Fuzzy matching algorithm:**
For each heading, check if all characters of `filterQuery` appear in `title` in order (case-insensitive). Score: +2 for consecutive matches, +1 for word-boundary matches (character after space, dash, or at string start), +0 otherwise. Return headings sorted by score descending, then by original order for ties.

**Tests** (`mkdnTests/Unit/Features/OutlineStateTests.swift`):
Use `@Suite("OutlineState")` and `@Test`. Use `@MainActor` on each test function.

Test cases:
1. `updateHeadings` with heading blocks → populates `headingTree` and `flatHeadings`
2. `updateHeadings` with no headings → both empty
3. `updateScrollPosition` with blockIndex after first heading → `isBreadcrumbVisible = true`, correct `breadcrumbPath`
4. `updateScrollPosition` with blockIndex before first heading → `isBreadcrumbVisible = false`, `currentHeadingIndex = nil`
5. `toggleHUD` when hidden → calls showHUD, `isHUDVisible = true`
6. `toggleHUD` when visible → calls dismissHUD, `isHUDVisible = false`
7. `showHUD` auto-selects current heading index
8. `dismissHUD` clears filterQuery
9. `filteredHeadings` with empty query → returns all flatHeadings
10. `filteredHeadings` with query "morch" and heading "Migration Orchestrator" → matches
11. `filteredHeadings` with query "xyz" and no matching headings → empty
12. `moveSelectionUp` wraps from 0 to last
13. `moveSelectionDown` wraps from last to 0
14. `selectAndNavigate` returns correct blockIndex and dismisses HUD

**Acceptance criteria:**
- `swift test --filter OutlineState` passes all tests
- `OutlineState` is `@MainActor @Observable`, matches `FindState` pattern
- Fuzzy filter matches fzf-style (in-order, non-adjacent, case-insensitive)
- `private(set)` on properties that should not be externally mutable
- SwiftLint and SwiftFormat pass

---

### T3. FocusedOutlineStateKey and App Layer Wiring
**Status:** done
**Depends on:** T2
**Files:** `mkdn/App/FocusedOutlineStateKey.swift` (new), `mkdn/App/DocumentWindow.swift` (modify), `mkdn/App/ContentView.swift` (modify)
**Review:** reviews/T3-review-1.md
**Spec:**

Wire OutlineState into the SwiftUI environment and focused-value system, following the exact pattern used by FindState.

**FocusedOutlineStateKey** (`mkdn/App/FocusedOutlineStateKey.swift`):
```swift
#if os(macOS)
import SwiftUI

public struct FocusedOutlineStateKey: FocusedValueKey {
    public typealias Value = OutlineState
}

public extension FocusedValues {
    var outlineState: OutlineState? {
        get { self[FocusedOutlineStateKey.self] }
        set { self[FocusedOutlineStateKey.self] = newValue }
    }
}
#endif
```
Follow exactly the pattern in `FocusedFindStateKey.swift`.

**DocumentWindow** (`mkdn/App/DocumentWindow.swift`):
Add `@State private var outlineState = OutlineState()` alongside the existing `findState`.
Add `.environment(outlineState)` alongside `.environment(findState)`.
Add `.focusedSceneValue(\.outlineState, outlineState)` alongside `.focusedSceneValue(\.findState, findState)`.

**ContentView** (`mkdn/App/ContentView.swift`):
Add `@Environment(OutlineState.self) private var outlineState` alongside `findState`.
Add `OutlineNavigatorView()` in the ZStack, after `FindBarView()`:
```swift
OutlineNavigatorView()
    .allowsHitTesting(outlineState.isHUDVisible || outlineState.isBreadcrumbVisible)
    .accessibilityHidden(!outlineState.isBreadcrumbVisible && !outlineState.isHUDVisible)
```

**Note:** `OutlineNavigatorView` will not exist yet when this task is built. Create a minimal placeholder:
```swift
// Temporary placeholder until T4/T5 builds the real view
struct OutlineNavigatorView: View {
    @Environment(OutlineState.self) private var outlineState
    var body: some View {
        EmptyView()
    }
}
```
Place in `mkdn/Features/Outline/Views/OutlineNavigatorView.swift`.

**How to test:**
- `swift build` succeeds with no errors
- The app launches and functions normally (no regressions)
- OutlineState is accessible via `@Environment(OutlineState.self)` in ContentView

**Acceptance criteria:**
- `FocusedOutlineStateKey` follows `FocusedFindStateKey` pattern exactly
- `DocumentWindow` creates, environments, and publishes `OutlineState`
- `ContentView` reads `OutlineState` from environment
- Placeholder `OutlineNavigatorView` compiles
- `swift build` passes
- SwiftLint and SwiftFormat pass

---

### T4. OutlineBreadcrumbBar — Breadcrumb Bar View
**Status:** done
**Depends on:** T2
**Files:** `mkdn/Features/Outline/Views/OutlineBreadcrumbBar.swift` (new)
**Review:** reviews/T4-review-1.md
**Spec:**

Build the collapsed breadcrumb bar that shows the current heading path.

**OutlineBreadcrumbBar** (`mkdn/Features/Outline/Views/OutlineBreadcrumbBar.swift`):
```swift
#if os(macOS)
import SwiftUI

struct OutlineBreadcrumbBar: View {
    let breadcrumbPath: [HeadingNode]
    let isVisible: Bool
    let onTap: () -> Void

    var body: some View {
        // ...
    }
}
#endif
```

**Visual design:**
- A single horizontal row of text segments separated by chevron characters ("›").
- Each segment shows the heading title from `breadcrumbPath`.
- Uses `.ultraThinMaterial` background with rounded corners (corner radius ~8).
- Text style: `.caption` or `.system(size: 12)`, foreground from theme's `foregroundSecondary`.
- Chevron separator: slightly dimmer than the text, e.g., `.tertiary` foreground style.
- Padding: horizontal 12, vertical 6 — thin and unobtrusive.
- Positioned at the top of the content area, centered horizontally.
- The entire bar is a single `Button` with `.plain` button style. Clicking anywhere calls `onTap`.
- Opacity: controlled by `isVisible` — 0 when false, 1 when true. Animated externally.

**Implementation:**
```swift
Button(action: onTap) {
    HStack(spacing: 4) {
        ForEach(Array(breadcrumbPath.enumerated()), id: \.element.id) { index, node in
            if index > 0 {
                Text("\u{203A}")  // single right-pointing angle quotation mark
                    .foregroundStyle(.tertiary)
            }
            Text(node.title)
                .lineLimit(1)
        }
    }
    .font(.system(size: 12, weight: .medium))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
.buttonStyle(.plain)
.opacity(isVisible ? 1 : 0)
```

**How to test:**
- This is a pure view with no state logic. Testing is visual.
- The builder should verify it compiles: `swift build`.
- Full visual verification happens in T7.

**Acceptance criteria:**
- Compiles with `swift build`
- Uses `.ultraThinMaterial` background
- Shows heading path with chevron separators
- Entire bar is a single click target (one `Button`)
- `isVisible` controls opacity
- SwiftLint and SwiftFormat pass

---

### T5. OutlineNavigatorView — HUD with Keyboard Navigation and Animation
**Status:** done
**Depends on:** T3, T4
**Files:** `mkdn/Features/Outline/Views/OutlineNavigatorView.swift` (replace placeholder from T3)
**Review:** reviews/T5-review-1.md
**Spec:**

Replace the placeholder `OutlineNavigatorView` with the full implementation combining the breadcrumb bar and the expanded outline HUD.

**OutlineNavigatorView** (`mkdn/Features/Outline/Views/OutlineNavigatorView.swift`):
- Reads `OutlineState` from environment.
- Reads `AppSettings` from environment (for theme colors).
- Reads `\.accessibilityReduceMotion` for animation resolution.
- Two visual states in a single view: breadcrumb (resting) and HUD (active).
- Positioned at top-center via `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`.

**Breadcrumb state (when `!isHUDVisible`):**
- Show `OutlineBreadcrumbBar` with `breadcrumbPath` from `outlineState`.
- `isVisible` = `outlineState.isBreadcrumbVisible`.
- `onTap` calls `outlineState.showHUD()` wrapped in `withAnimation(motion.resolved(.springSettle))`.
- Animate breadcrumb visibility with `motion.resolved(.fadeIn)` / `motion.resolved(.fadeOut)`.

**HUD state (when `isHUDVisible`):**
- Expand from the breadcrumb position downward with spring animation.
- `.ultraThinMaterial` background, rounded corners (12pt).
- Max width: 400pt. Max height: 60% of available height (use `GeometryReader` or fixed reasonable max like 500pt).
- Shadow: `.shadow(color: .black.opacity(0.15), radius: 8, y: 4)`.

**HUD content:**
1. **Filter field** at the top: `TextField("Filter headings\u{2026}", text: $outlineState.filterQuery)` with magnifying glass icon. Styled like the find bar's text field. Uses `@FocusState` to auto-focus on appear.
2. **Heading list** below: `ScrollViewReader` > `ScrollView` > `LazyVStack(alignment: .leading, spacing: 0)` showing `outlineState.filteredHeadings`.
   - Each row shows the heading title with left-padding proportional to `(node.level - 1) * 16` points.
   - The selected row (`selectedIndex`) has an accent background highlight (theme's `accent.opacity(0.15)`).
   - The current heading (matching `currentHeadingIndex`) has a subtle marker (e.g., a small dot or different text weight).
   - Row height: ~32pt. Font: `.system(size: 13)`.
   - Each row is a `Button` that calls `selectAndNavigate()` on tap.
   - Use `.id(node.id)` on each row for `ScrollViewReader.scrollTo()`.
3. On HUD appear, scroll to the currently selected heading: `.onAppear { proxy.scrollTo(selectedHeadingID, anchor: .center) }`.
4. On HUD appear, focus the filter field via `@FocusState`.

**Keyboard handling** (via `.onKeyPress` on the outer container):
- **Down arrow**: `outlineState.moveSelectionDown()`; scroll to new selection.
- **Up arrow**: `outlineState.moveSelectionUp()`; scroll to new selection.
- **Enter/Return**: call `outlineState.selectAndNavigate()`, trigger scroll-to-heading (store result in state for the Coordinator to pick up via a published property; or post a notification). Dismiss HUD with animation.
- **Escape**: call `outlineState.dismissHUD()` with animation.
- Character keys: handled automatically by the focused `TextField`.

**Animation:**
- HUD expand: `withAnimation(motion.resolved(.springSettle))` when `isHUDVisible` changes.
- Use `.transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))` or similar on the HUD content.
- With Reduce Motion: use `reducedCrossfade` instead of spring.

**Scroll-to-heading on selection:**
- When `selectAndNavigate()` returns a `blockIndex`, store it as `outlineState.pendingScrollTarget: Int?` (add this property to OutlineState in this task).
- The Coordinator (in T6) will observe this and perform the actual scroll.

**Implementation note on `pendingScrollTarget`:**
Add to `OutlineState`:
```swift
public var pendingScrollTarget: Int?  // blockIndex to scroll to; consumed by Coordinator
```
Set in `selectAndNavigate()`, consumed (set to nil) by the Coordinator after scrolling.

**Click-outside-to-dismiss:**
- Add a full-screen transparent background behind the HUD (but in front of content) when `isHUDVisible`:
```swift
if outlineState.isHUDVisible {
    Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(motion.resolved(.springSettle)) {
                outlineState.dismissHUD()
            }
        }
}
```

**How to test:**
- `swift build` passes.
- Unit tests for OutlineState (from T2) cover the logic. The view itself is verified visually in T7.

**Acceptance criteria:**
- Replaces the placeholder from T3
- Two visual states: breadcrumb bar and HUD
- HUD shows filter field + scrollable heading list with level-based indentation
- Keyboard navigation (up/down/enter/escape) works
- Click-outside-to-dismiss works (FR-20)
- `pendingScrollTarget` added to OutlineState
- Spring animation for expand/collapse, with Reduce Motion fallback
- SwiftLint and SwiftFormat pass
- `swift build` passes

---

### T6. Scroll-Spy and Heading Data Feed — Coordinator Integration
**Status:** done
**Depends on:** T1, T2, T3
**Files:** `mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift` (modify), `mkdn/Features/Viewer/Views/SelectableTextView.swift` (modify), `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` (modify)
**Review:** reviews/T6-review-1.md
**Spec:**

Wire the scroll-spy mechanism and heading data feed into the existing rendering pipeline.

**MarkdownPreviewView changes:**
- Add `@Environment(OutlineState.self) private var outlineState`.
- In `renderAndBuild`, after setting `renderedBlocks`, call `outlineState.updateHeadings(from: newBlocks)`.
- This ensures the heading tree is rebuilt whenever the document content changes.

```swift
private func renderAndBuild(_ newBlocks: [IndexedBlock], isFullReload animate: Bool) {
    renderedBlocks = newBlocks
    knownBlockIDs = Set(newBlocks.map(\.id))
    isFullReload = animate
    textStorageResult = MarkdownTextStorageBuilder.build(
        blocks: newBlocks,
        theme: appSettings.theme,
        scaleFactor: appSettings.scaleFactor
    )
    outlineState.updateHeadings(from: newBlocks)  // NEW
}
```

**SelectableTextView changes:**
- Add `let outlineState: OutlineState` property (passed from MarkdownPreviewView).
- Pass `outlineState` to the Coordinator in `makeNSView`.
- In MarkdownPreviewView, pass `outlineState: outlineState` when constructing `SelectableTextView`.

**SelectableTextView+Coordinator changes:**
Add scroll-spy to the Coordinator:

1. Add `weak var outlineState: OutlineState?` property.
2. Add `var scrollObserver: NSObjectProtocol?` property for the notification observer.
3. In `makeNSView`, after setting `coordinator.textView`:
   ```swift
   coordinator.outlineState = outlineState
   coordinator.startScrollSpy(on: scrollView)
   ```
4. Implement `startScrollSpy(on:)`:
   ```swift
   func startScrollSpy(on scrollView: NSScrollView) {
       let clipView = scrollView.contentView
       clipView.postsBoundsChangedNotifications = true
       scrollObserver = NotificationCenter.default.addObserver(
           forName: NSView.boundsDidChangeNotification,
           object: clipView, queue: .main
       ) { [weak self] _ in
           Task { @MainActor [weak self] in
               self?.handleScrollForSpy()
           }
       }
   }
   ```
5. Implement `handleScrollForSpy()`:
   - Read `clipView.bounds.origin.y` (viewport top).
   - Use the text layout manager to find which heading is at or above the viewport top.
   - Call `outlineState.updateScrollPosition(currentBlockIndex:)`.

   **Mapping y-position to heading block index:**
   - The Coordinator needs to know which character ranges correspond to heading blocks.
   - Approach: `OutlineState` stores the `flatHeadings` array with `blockIndex` values. The Coordinator iterates these heading block indices, maps each to a character range in the text storage, then uses `enumerateTextLayoutFragments` to get the y-position.
   - For efficiency, cache the heading y-positions after layout and invalidate on content change. On each scroll event, binary search the cached positions for the last heading at or above the viewport top.

   **Simplified initial approach** (avoid premature optimization):
   - On each scroll event, iterate `outlineState.flatHeadings` in reverse.
   - For each heading, use the text layout manager to get its fragment y-position.
   - Return the first heading whose y <= viewport top.
   - This is O(n) where n = number of headings, which is fast for ~30 headings.

   **Getting a heading's y-position from its blockIndex:**
   - The text storage is built from `[IndexedBlock]` sequentially. Each block maps to a range of characters. To find the character offset of block `i`, we need a mapping.
   - Add a `blockRanges: [Int: NSRange]` dictionary to `OutlineState` (or compute it from the text storage).
   - Better approach: during `MarkdownTextStorageBuilder.build()`, track the character offset of each block. But that modifies core code.
   - **Pragmatic approach:** Search the text storage for heading text. Each heading in `flatHeadings` has a `title`. Use `NSString.range(of:)` to find the heading text in the text storage. This is simple but could fail for duplicate heading text.
   - **Best approach for this codebase:** The `MarkdownTextStorageBuilder` appends blocks sequentially and each heading is preceded by `\n` separators. Use the block index to walk through the text storage's paragraphs. Each `\n\n` boundary roughly corresponds to a block boundary. However, this is fragile.
   - **Recommended approach:** Add a `headingCharacterOffsets: [Int: Int]` property to `TextStorageResult`. During `MarkdownTextStorageBuilder.build()`, record `result.length` before each heading block is appended. This is a minimal, non-intrusive change to the builder.

   **TextStorageResult change** (minimal):
   Add `public let headingOffsets: [Int: Int]` to `TextStorageResult` — maps `blockIndex` to character offset in the attributed string.

   **MarkdownTextStorageBuilder change** (minimal):
   In the build loop, before processing each block, if the block is a `.heading`, record `(blockIndex, result.length)` in a dictionary. Pass this dictionary to the `TextStorageResult` initializer.

   These changes touch:
   - `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` (add recording in build loop)
   - `mkdn/Core/Markdown/TextStorageResult` — wherever `TextStorageResult` is defined (find it)

6. Implement **scroll-to-heading** (consuming `pendingScrollTarget`):
   - In `updateNSView`, check if `outlineState.pendingScrollTarget` is set.
   - If so, find the y-position of that heading using the heading offset + layout manager.
   - Scroll to that position: `scrollView.contentView.scroll(to: NSPoint(x: 0, y: headingY))` + `scrollView.reflectScrolledClipView(scrollView.contentView)`.
   - Set `outlineState.pendingScrollTarget = nil`.

**How to test:**
- `swift build` passes.
- Manual verification: open a Markdown file with headings, scroll down, verify breadcrumb appears.
- The scroll-spy logic itself is tested indirectly via OutlineState tests (T2) — the state transitions are tested there.
- Add a simple integration test if feasible: create a text storage, call the y-mapping logic, verify it returns reasonable values. This may be difficult to unit test without an actual NSTextView, so manual/visual verification in T7 is the primary validation.

**Acceptance criteria:**
- Scroll past first heading → breadcrumb appears with correct path
- Scroll back above first heading → breadcrumb disappears
- `pendingScrollTarget` consumed by Coordinator → view scrolls to heading
- Heading character offsets tracked in `TextStorageResult`
- No performance regression (scroll events are lightweight)
- `swift build` passes
- SwiftLint and SwiftFormat pass

---

### T7. Cmd+J Registration, Polish, and Visual Verification
**Status:** done
**Depends on:** T5, T6
**Files:** `mkdn/App/MkdnCommands.swift` (modify)
**Review:** reviews/T7-review-1.md
**Spec:**

Register the Cmd+J keyboard shortcut and perform end-to-end visual verification.

**MkdnCommands changes:**
- Add `@FocusedValue(\.outlineState) private var outlineState`.
- Add a "Document Outline" button in the View section (within the `CommandGroup(after: .sidebar)` block, in a new `Section`):
```swift
Section {
    Button("Document Outline") {
        withAnimation(motionAnimation(.springSettle)) {
            outlineState?.toggleHUD()
        }
    }
    .keyboardShortcut("j", modifiers: .command)
    .disabled(outlineState?.headingTree.isEmpty ?? true)
}
```

**Visual verification workflow (per CLAUDE.md):**
1. `swift build`
2. Launch test harness: `swift run mkdn --test-harness &`
3. Load a fixture with multiple heading levels. If no suitable fixture exists, create `fixtures/outline-test.md` with:
   - An h1, two h2s under it, h3s under the second h2
   - A second h1 with one h2
   - Paragraphs and code blocks between headings
   - At least 100 lines total to ensure scrollability
4. `scripts/mkdn-ctl load fixtures/outline-test.md`
5. Capture screenshots at scroll=0 (breadcrumb should be invisible)
6. `scripts/mkdn-ctl scroll 300` — capture (breadcrumb should appear)
7. Capture in both themes: `scripts/mkdn-ctl theme solarizedLight` + capture, `scripts/mkdn-ctl theme solarizedDark` + capture
8. Read each PNG to visually inspect:
   - Breadcrumb bar appearance, positioning, text legibility
   - Theme harmony in both light and dark
   - Material background transparency
9. **Manual Cmd+J test** (describe expected behavior; harness cannot simulate keyboard shortcuts):
   - Cmd+J opens HUD from breadcrumb position
   - Heading tree shows correct hierarchy with indentation
   - Typing filters headings
   - Arrow keys navigate
   - Enter scrolls to heading and dismisses
   - Escape dismisses without navigation
   - Click outside dismisses

**Fixture file** (`fixtures/outline-test.md`):
Create if it does not already exist. Content should exercise:
- Multiple heading levels (h1, h2, h3)
- Multiple root headings
- Enough body text between headings to require scrolling
- A heading with long text to test truncation

**How to test:**
- `swift build` and `swift test` both pass (all existing + new tests)
- Visual verification via test harness confirms breadcrumb and HUD render correctly
- Cmd+J menu item appears in View menu
- Menu item is disabled when document has no headings (e.g., welcome screen)
- SwiftLint and SwiftFormat pass

**Acceptance criteria:**
- Cmd+J registered in View menu as "Document Outline"
- Menu item disabled when no headings present
- Visual verification screenshots captured and inspected in both themes
- All prior tasks' functionality works end-to-end
- No regressions in existing functionality
- SwiftLint and SwiftFormat pass

---

### T8. Cache filteredHeadings in OutlineState
**Status:** done
**Depends on:** —
**Files:** `mkdn/Features/Outline/ViewModels/OutlineState.swift` (modify), `mkdnTests/Unit/Features/OutlineStateTests.swift` (modify)
**Review:** reviews/T8-review-1.md
**Spec:**

**Problem:** `filteredHeadings` is a computed property that recomputes fuzzy scoring on every access. It is accessed multiple times per render cycle (by the heading list, by `moveSelectionUp`/`moveSelectionDown`, by the `onChange` handler for `filterQuery`, by `scrollToSelection`). Each access rescans all headings and re-sorts. This is wasteful and architecturally wrong for `@Observable` — the property triggers observation tracking on every call.

**Fix:** Convert `filteredHeadings` from a computed property to a cached stored property, recomputed via a single `applyFilter()` method. Move `selectedIndex` clamping into `applyFilter()` so the state class maintains its own invariants.

**Implementation:**

1. Replace the computed `filteredHeadings` with a stored property:
   ```swift
   public private(set) var filteredHeadings: [HeadingNode] = []
   ```

2. Add a public `applyFilter()` method that recomputes `filteredHeadings` AND clamps `selectedIndex`:
   ```swift
   public func applyFilter() {
       if filterQuery.isEmpty {
           filteredHeadings = flatHeadings
       } else {
           let queryChars = Array(filterQuery.lowercased())
           var scored: [(node: HeadingNode, score: Int, originalIndex: Int)] = []
           for (originalIndex, node) in flatHeadings.enumerated() {
               if let score = fuzzyScore(query: queryChars, target: node.title.lowercased()) {
                   scored.append((node, score, originalIndex))
               }
           }
           scored.sort { lhs, rhs in
               if lhs.score != rhs.score { return lhs.score > rhs.score }
               return lhs.originalIndex < rhs.originalIndex
           }
           filteredHeadings = scored.map(\.node)
       }

       // Clamp selectedIndex to valid range.
       if filteredHeadings.isEmpty {
           selectedIndex = 0
       } else if selectedIndex >= filteredHeadings.count {
           selectedIndex = filteredHeadings.count - 1
       }
   }
   ```

3. Call `applyFilter()` at the end of these methods:
   - `updateHeadings(from:)` — after setting `flatHeadings`
   - `showHUD()` — after resetting `filterQuery = ""`
   - `dismissHUD()` — after resetting `filterQuery = ""`

4. The view's `.onChange(of: outlineState.filterQuery)` handler in T11 also calls `outlineState.applyFilter()` for the typing case (TextField binding mutates `filterQuery` directly). The handler no longer needs its own `selectedIndex` clamping — `applyFilter()` handles it.

5. The private `fuzzyScore` helper method stays as-is.

**Tests:**
- All existing OutlineState tests should still pass — the observable behavior is identical, just cached.
- Add a test: set `filterQuery` then call `applyFilter()`, verify `filteredHeadings` is correct.
- Add a test: verify `selectedIndex` is clamped when `applyFilter()` reduces the list below the current `selectedIndex`.

**How to test:**
- `swift test --filter OutlineState` — all existing tests pass.
- `swift build` passes.

**Acceptance criteria:**
- `filteredHeadings` is a stored `public private(set) var`, not a computed property
- `applyFilter()` recomputes `filteredHeadings` AND clamps `selectedIndex` — the state class owns its invariants
- `applyFilter()` is called from `updateHeadings`, `showHUD`, `dismissHUD`, and from the view's `.onChange(of: filterQuery)` handler (T11)
- All existing OutlineState tests pass without modification (or with minimal adjustment)
- `swift build` and `swift test` pass
- SwiftLint and SwiftFormat pass

---

### T9. Breadcrumb Bar Max Width and Truncation
**Status:** done
**Depends on:** —
**Files:** `mkdn/Features/Outline/Views/OutlineBreadcrumbBar.swift` (modify)
**Review:** reviews/T9-review-1.md
**Spec:**

**Problem:** The breadcrumb bar has no max width or truncation strategy. For deeply nested headings (e.g., h1 > h2 > h3 > h4), the breadcrumb can grow arbitrarily wide, potentially overflowing the viewport or looking awkward.

**Fix:** Add a max width constraint and truncation behavior to the breadcrumb bar.

**Implementation:**

1. Add `.frame(maxWidth: 500)` to the outer `HStack` or the `Button` content — this caps the breadcrumb at a reasonable width that fits most window sizes.

2. Add `.truncationMode(.middle)` to the individual heading `Text` views — so "Migration Orchestrator Implementation" becomes "Migration...mentation" when space is tight, preserving both the start and end of the title.

3. Each heading segment should have `.truncationMode(.middle)` and `.lineLimit(1)` (lineLimit already present).

4. The breadcrumb HStack should be wrapped in a container that clips overflow:
   ```swift
   Button(action: onTap) {
       HStack(spacing: 4) {
           ForEach(Array(breadcrumbPath.enumerated()), id: \.element.id) { index, node in
               if index > 0 {
                   Text("\u{203A}")
                       .foregroundStyle(.tertiary)
                       .layoutPriority(1) // Chevrons should not truncate
               }
               Text(node.title)
                   .lineLimit(1)
                   .truncationMode(.middle)
           }
       }
       .font(.system(size: 12, weight: .medium))
       .foregroundStyle(.secondary)
       .padding(.horizontal, 12)
       .padding(.vertical, 6)
       .background(.ultraThinMaterial)
       .clipShape(RoundedRectangle(cornerRadius: 8))
   }
   .buttonStyle(.plain)
   .frame(maxWidth: 500)
   .opacity(isVisible ? 1 : 0)
   ```

**How to test:**
- `swift build` passes.
- Visual verification in T12: load a document with deeply nested headings (h1 > h2 > h3 > h4) and long heading titles. Breadcrumb should truncate gracefully, not overflow.

**Acceptance criteria:**
- Breadcrumb bar has a max width of ~500pt
- Individual heading segments use `.truncationMode(.middle)`
- Chevron separators do not truncate (use `layoutPriority`)
- `swift build` passes
- SwiftLint and SwiftFormat pass

---

### T10. Cache Heading Y-Positions for Scroll-Spy Performance
**Status:** done
**Depends on:** —
**Files:** `mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift` (modify), `mkdn/Features/Viewer/Views/SelectableTextView.swift` (modify)
**Review:** reviews/T10-review-1.md
**Spec:**

**Problem:** `handleScrollForSpy()` calls `yPosition(forCharacterOffset:)` with `.ensuresLayout` for every heading on every scroll event. With 30 headings at 60fps, that is up to 1800 forced layout queries per second. Heading y-positions do not change during scrolling — they change only when the content changes (new document loaded, text storage replaced) or the view resizes.

**Fix:** Cache heading y-positions after layout, invalidate on content change. On each scroll event, binary-search the cache instead of querying the layout manager.

**Design note:** `.ensuresLayout` is intentionally kept in `yPosition(forCharacterOffset:)` — this method is used for cache-building (runs infrequently, on content/resize change) and for `scrollToHeading()` (runs on user action). The performance win comes from removing it from the scroll-event hot path, which now reads from the cache.

**Implementation:**

1. Add cached position storage to the Coordinator:
   ```swift
   /// Cached heading y-positions for scroll-spy. Maps blockIndex to y-coordinate.
   /// Invalidated when content changes or view resizes.
   private var cachedHeadingPositions: [(blockIndex: Int, y: CGFloat)] = []
   private var headingPositionsCacheValid = false
   ```

2. Add `var frameObserver: NSObjectProtocol?` alongside `scrollObserver`.

3. Add a method to rebuild the cache:
   ```swift
   private func rebuildHeadingPositionCache() {
       guard let outlineState else {
           cachedHeadingPositions = []
           headingPositionsCacheValid = false
           return
       }

       var positions: [(blockIndex: Int, y: CGFloat)] = []
       for heading in outlineState.flatHeadings {
           guard let charOffset = headingOffsets[heading.blockIndex],
                 let y = yPosition(forCharacterOffset: charOffset)
           else { continue }
           positions.append((blockIndex: heading.blockIndex, y: y))
       }
       // Sort by y ascending for binary search.
       positions.sort { $0.y < $1.y }
       cachedHeadingPositions = positions
       headingPositionsCacheValid = true
   }
   ```

4. Add `func invalidateHeadingPositionCache()` that sets `headingPositionsCacheValid = false` and clears `cachedHeadingPositions = []`.

5. **Compare headingOffsets before invalidating in `updateNSView`:**
   In `SelectableTextView.swift`, change the `updateNSView` heading offsets update from:
   ```swift
   coordinator.headingOffsets = headingOffsets
   ```
   To:
   ```swift
   if coordinator.headingOffsets != headingOffsets {
       coordinator.headingOffsets = headingOffsets
       coordinator.invalidateHeadingPositionCache()
   }
   ```
   This prevents cache invalidation on every render cycle — the cache is only invalidated when the offsets actually change.

6. Invalidate on view resize. In `startScrollSpy`, add a `NSView.frameDidChangeNotification` observer:
   ```swift
   // Also observe frame changes for cache invalidation.
   textView?.postsFrameChangedNotifications = true
   frameObserver = NotificationCenter.default.addObserver(
       forName: NSView.frameDidChangeNotification,
       object: textView,
       queue: .main
   ) { [weak self] _ in
       Task { @MainActor [weak self] in
           self?.headingPositionsCacheValid = false
       }
   }
   ```
   Clean up any existing `frameObserver` at the start of `startScrollSpy`, same pattern as `scrollObserver`.

7. Add explicit `deinit` to the Coordinator that removes both observers:
   ```swift
   deinit {
       if let scrollObserver {
           NotificationCenter.default.removeObserver(scrollObserver)
       }
       if let frameObserver {
           NotificationCenter.default.removeObserver(frameObserver)
       }
   }
   ```

8. Rewrite `handleScrollForSpy()` to use the cache:
   ```swift
   func handleScrollForSpy() {
       guard let textView,
             let scrollView = textView.enclosingScrollView,
             let outlineState
       else { return }

       let viewportTop = scrollView.contentView.bounds.origin.y
       let flatHeadings = outlineState.flatHeadings
       guard !flatHeadings.isEmpty else { return }

       // Lazily rebuild cache if invalid.
       if !headingPositionsCacheValid {
           rebuildHeadingPositionCache()
       }

       guard !cachedHeadingPositions.isEmpty else {
           let firstBlockIndex = flatHeadings.first?.blockIndex ?? 0
           outlineState.updateScrollPosition(currentBlockIndex: firstBlockIndex - 1)
           return
       }

       // Binary search for the last heading at or above viewportTop.
       var low = 0
       var high = cachedHeadingPositions.count - 1
       var bestIndex = -1
       while low <= high {
           let mid = (low + high) / 2
           if cachedHeadingPositions[mid].y <= viewportTop {
               bestIndex = mid
               low = mid + 1
           } else {
               high = mid - 1
           }
       }

       if bestIndex >= 0 {
           outlineState.updateScrollPosition(
               currentBlockIndex: cachedHeadingPositions[bestIndex].blockIndex
           )
       } else {
           let firstBlockIndex = flatHeadings.first?.blockIndex ?? 0
           outlineState.updateScrollPosition(currentBlockIndex: firstBlockIndex - 1)
       }
   }
   ```

9. The existing `yPosition(forCharacterOffset:)` method stays as-is with `.ensuresLayout` (used by `rebuildHeadingPositionCache()` and `scrollToHeading()`).

**How to test:**
- `swift build` passes.
- Existing scroll-spy behavior is preserved: breadcrumb shows correct heading path at all scroll positions.
- Performance improvement: no `.ensuresLayout` calls during steady-state scrolling. Cache rebuilds only on content change or resize.

**Acceptance criteria:**
- `handleScrollForSpy()` does zero `enumerateTextLayoutFragments` calls when the cache is valid
- Cache is invalidated only when `headingOffsets` actually changes (compared before assignment) or text view frame changes (resize)
- `headingOffsets` comparison in `updateNSView` prevents spurious invalidation on every render cycle
- Cache is lazily rebuilt on the next scroll event after invalidation
- Binary search is used for O(log n) lookup instead of O(n) linear scan with layout queries
- `scrollToHeading` still works correctly (uses `yPosition` directly, not the cache)
- Explicit `deinit` removes both `scrollObserver` and `frameObserver`
- `swift build` passes
- SwiftLint and SwiftFormat pass

---

### T11. Rebuild OutlineNavigatorView as Single Morphing Component
**Status:** done
**Depends on:** T8, T9
**Files:** `mkdn/Features/Outline/Views/OutlineNavigatorView.swift` (rewrite), `mkdn/Features/Viewer/Views/SelectableTextView.swift` (modify)
**Review:** reviews/T11-review-1.md
**Spec:**

**Problem (MAJOR):** The current `OutlineNavigatorView` uses `if/else` view swapping between breadcrumb and HUD with `.move(edge: .top)` transition. The architecture doc and context doc both explicitly state: "the breadcrumb IS the HUD in collapsed form" and "two states of ONE component, not two separate views." The current implementation creates and destroys separate view trees on toggle, which makes the animation disjoint — the breadcrumb disappears and a HUD slides in from above, rather than the breadcrumb expanding in place into the HUD.

**Additional fix (minor):** The current code mutates `outlineState.pendingScrollTarget = nil` inside `updateNSView` in `SelectableTextView.swift` (line 118). This is a state mutation during the SwiftUI render cycle, which triggers an unnecessary re-render. Additionally, the async nil-out approach risks double-scrolling if `updateNSView` fires again before the Task runs.

**Fix:** Rebuild `OutlineNavigatorView` as a single view with a shared container that morphs between breadcrumb and HUD states. The `if/else` is allowed for the CONTENT inside the container, but the CONTAINER itself (frame, background, clipShape, shadow, cornerRadius) is shared and animates continuously. The visual result is an expanding/collapsing box with content cross-fading inside.

**Architecture:**

The single component has two visual states driven by `outlineState.isHUDVisible`:
- **Collapsed (breadcrumb):** Small pill, shows heading path, thin height (~32pt), max width ~500pt (from T9), corner radius 8.
- **Expanded (HUD):** Larger panel, shows filter + heading list, taller (up to 500pt), max width 400pt, corner radius 12.

Both states share the SAME outer container with `.ultraThinMaterial` background. The container's dimensions animate smoothly between the two states via `withAnimation(.springSettle)`. Content inside the container uses `if/else` with cross-fade transitions.

**`OutlineBreadcrumbBar.swift`:** Keep the file as-is. It is a valid standalone component. T11 inlines the breadcrumb content in the morphing container but does NOT delete `OutlineBreadcrumbBar.swift`.

**Implementation:**

1. **Single container with shared shell:**
   ```swift
   struct OutlineNavigatorView: View {
       @Environment(OutlineState.self) private var outlineState
       @Environment(AppSettings.self) private var appSettings
       @Environment(\.accessibilityReduceMotion) private var reduceMotion
       @FocusState private var isFilterFocused: Bool

       private var isExpanded: Bool { outlineState.isHUDVisible }

       private var motion: MotionPreference {
           MotionPreference(reduceMotion: reduceMotion)
       }

       var body: some View {
           ZStack(alignment: .top) {
               // Click-outside-to-dismiss scrim (only when expanded).
               if isExpanded {
                   Color.clear
                       .contentShape(Rectangle())
                       .onTapGesture {
                           withAnimation(motion.resolved(.springSettle)) {
                               outlineState.dismissHUD()
                           }
                       }
               }

               // Single morphing container.
               outlineContainer
                   .padding(.top, 8)
           }
           .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
       }

       // MARK: - Morphing Container
       // The CONTAINER (frame, background, clipShape, shadow, cornerRadius)
       // is shared and animates continuously. Content cross-fades inside.

       private var outlineContainer: some View {
           VStack(spacing: 0) {
               if isExpanded {
                   filterField
                       .padding(.horizontal, 12)
                       .padding(.top, 10)
                       .padding(.bottom, 6)
                       .transition(.opacity)

                   Divider()
                       .padding(.horizontal, 8)
                       .transition(.opacity)

                   headingList
                       .transition(.opacity)
               } else {
                   breadcrumbContent
                       .transition(.opacity)
               }
           }
           // SHARED container shell — these animate continuously:
           .frame(maxWidth: isExpanded ? 400 : 500)
           .frame(maxHeight: isExpanded ? 500 : nil)
           .background(.ultraThinMaterial)
           .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 12 : 8))
           .shadow(
               color: isExpanded ? .black.opacity(0.15) : .clear,
               radius: isExpanded ? 8 : 0,
               y: isExpanded ? 4 : 0
           )
           .opacity(outlineState.isBreadcrumbVisible || isExpanded ? 1 : 0)
           .animation(motion.resolved(.springSettle), value: isExpanded)
           .animation(motion.resolved(.fadeIn), value: outlineState.isBreadcrumbVisible)
           .padding(.horizontal, 16)
           .onKeyPress(.upArrow, phases: .down) { _ in
               guard isExpanded else { return .ignored }
               outlineState.moveSelectionUp()
               return .handled
           }
           .onKeyPress(.downArrow, phases: .down) { _ in
               guard isExpanded else { return .ignored }
               outlineState.moveSelectionDown()
               return .handled
           }
           .onKeyPress(.return, phases: .down) { _ in
               guard isExpanded else { return .ignored }
               withAnimation(motion.resolved(.springSettle)) {
                   _ = outlineState.selectAndNavigate()
               }
               return .handled
           }
           .onKeyPress(.escape, phases: .down) { _ in
               guard isExpanded else { return .ignored }
               withAnimation(motion.resolved(.springSettle)) {
                   outlineState.dismissHUD()
               }
               return .handled
           }
           .onChange(of: outlineState.isHUDVisible) { _, isVisible in
               if isVisible {
                   DispatchQueue.main.async {
                       isFilterFocused = true
                   }
               }
           }
           .onChange(of: outlineState.filterQuery) { _, _ in
               outlineState.applyFilter()
           }
       }
   }
   ```

2. **`breadcrumbContent`** — inlined breadcrumb (no background, the shared container provides it):
   ```swift
   private var breadcrumbContent: some View {
       Button {
           withAnimation(motion.resolved(.springSettle)) {
               outlineState.showHUD()
           }
       } label: {
           HStack(spacing: 4) {
               ForEach(
                   Array(outlineState.breadcrumbPath.enumerated()),
                   id: \.element.id
               ) { index, node in
                   if index > 0 {
                       Text("\u{203A}")
                           .foregroundStyle(.tertiary)
                           .layoutPriority(1)
                   }
                   Text(node.title)
                       .lineLimit(1)
                       .truncationMode(.middle)
               }
           }
           .font(.system(size: 12, weight: .medium))
           .foregroundStyle(.secondary)
           .padding(.horizontal, 12)
           .padding(.vertical, 6)
       }
       .buttonStyle(.plain)
   }
   ```

3. **Fix `pendingScrollTarget` double-scroll risk:**
   In `SelectableTextView+Coordinator`, add a tracking property:
   ```swift
   var lastScrolledTarget: Int?
   ```

   In `SelectableTextView.swift`, change the `pendingScrollTarget` consumption from:
   ```swift
   // Current (BAD — mutates state during render, risks double-scroll):
   if let targetBlockIndex = outlineState.pendingScrollTarget {
       coordinator.scrollToHeading(blockIndex: targetBlockIndex, in: scrollView)
       outlineState.pendingScrollTarget = nil
   }
   ```
   To:
   ```swift
   // Fixed — skip if already scrolled to this target:
   if let targetBlockIndex = outlineState.pendingScrollTarget,
      targetBlockIndex != coordinator.lastScrolledTarget {
       coordinator.lastScrolledTarget = targetBlockIndex
       coordinator.scrollToHeading(blockIndex: targetBlockIndex, in: scrollView)
       Task { @MainActor in
           outlineState.pendingScrollTarget = nil
       }
   }
   ```
   Reset `lastScrolledTarget` when content changes. In the `isNewContent` block of `updateNSView`, add:
   ```swift
   coordinator.lastScrolledTarget = nil
   ```

4. **`filterField` `.onChange` handler:** The `.onChange(of: outlineState.filterQuery)` handler now calls `outlineState.applyFilter()` (from T8). The `selectedIndex` clamping that was previously in this handler is no longer needed here — `applyFilter()` handles it internally. Remove the old clamping code from the `filterField` computed property's `.onChange` handler.

5. **`filterField` and `headingList`:** Keep the same implementation from the current `OutlineNavigatorView` — these computed properties (`filterField`, `headingList`, `headingRow`, `scrollToSelection`) are unchanged except for the `.onChange` update noted above.

**How to test:**
- `swift build` passes.
- `swift test` passes (no view logic tests to break, OutlineState tests unchanged).
- Visual verification in T12:
  - Breadcrumb bar appears at correct position, fades in/out with scroll.
  - Clicking breadcrumb or pressing Cmd+J: the shared material container expands smoothly from breadcrumb size to HUD size. Content cross-fades inside the expanding box.
  - Dismissing the HUD: the container shrinks back to breadcrumb size smoothly.
  - No disjoint slide-in/slide-out effect. The transition is a continuous morph of the container with content cross-fading.
  - Keyboard navigation (up/down/enter/escape) works in HUD mode.
  - Click-outside-to-dismiss works.

**Acceptance criteria:**
- Container (frame, background, clipShape, shadow, cornerRadius) is SHARED between breadcrumb and HUD states and animates continuously
- Content inside uses `if/else` with `.transition(.opacity)` for cross-fade
- `.ultraThinMaterial` background is on the outer container, shared between both states
- Container dimensions animate via `springSettle` (width, height, corner radius, shadow)
- `pendingScrollTarget` uses `lastScrolledTarget` tracking to prevent double-scroll; `lastScrolledTarget` resets on content change
- `.onChange(of: outlineState.filterQuery)` calls `outlineState.applyFilter()` (from T8)
- `OutlineBreadcrumbBar.swift` is kept as-is (not deleted)
- All keyboard navigation works
- Filter field auto-focuses on HUD open
- `swift build` and `swift test` pass
- SwiftLint and SwiftFormat pass

---

### T12. Visual Verification of All Fixes
**Status:** done
**Depends on:** T10, T11
**Files:** —
**Review:** reviews/T12-review-1.md
**Spec:**

Perform end-to-end visual verification of all fix tasks, focusing on the animation quality and scroll-spy performance.

**Visual verification workflow:**

1. `swift build`
2. Launch test harness: `swift run mkdn --test-harness &`
3. Load outline fixture: `scripts/mkdn-ctl load fixtures/outline-test.md`

**Breadcrumb tests:**
4. Scroll to 0 — capture screenshot. Breadcrumb should be invisible.
5. Scroll to 300 — capture screenshot. Breadcrumb should appear with correct heading path. Verify it is within max width, truncating if headings are long.
6. Switch themes and capture in both solarizedLight and solarizedDark.
7. Read each screenshot to verify:
   - Breadcrumb text is legible and properly truncated
   - Material background is visible
   - Positioning is correct (top-center)

**Morph animation tests (manual, describe expected):**
8. Verify that clicking the breadcrumb causes it to EXPAND IN PLACE into the HUD — the material background grows, the heading list appears inside the same container. NO slide-from-top effect.
9. Verify that pressing Escape causes the HUD to SHRINK back to breadcrumb size — reverse of the expand.
10. Verify the animation is smooth spring, not jarring.

**Scroll-spy performance (manual):**
11. Load a fixture with many headings (outline-test.md has several). Scroll rapidly up and down. Breadcrumb updates should be smooth with no jank. No visible performance degradation.

**Full interaction test (manual):**
12. Cmd+J opens HUD. Type a filter query — headings filter. Arrow keys navigate. Enter jumps to heading. Escape dismisses. Click outside dismisses.

**Acceptance criteria:**
- All screenshots show correct rendering in both themes
- Morph animation is a continuous expansion/contraction (not a view swap)
- No visible scroll jank during rapid scrolling
- All keyboard and mouse interactions work correctly
- `swift build` and `swift test` pass with no regressions
- SwiftLint and SwiftFormat pass
