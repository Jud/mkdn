# Development Tasks: Custom Find Bar

**Feature ID**: custom-find-bar
**Status**: In Progress
**Progress**: 15% (2 of 13 tasks)
**Estimated Effort**: 4.5 days
**Started**: 2026-02-15

## Overview

Replace the stock NSTextFinder find bar with a custom SwiftUI pill-shaped find bar that floats in the top-right corner of the preview viewport. The find bar is a SwiftUI overlay in the ContentView ZStack (highest z-order), backed by a per-window `FindState` observable that bridges search state between the SwiftUI find bar UI, the NSTextView Coordinator (for highlight rendering and scroll), and the menu command system (for keyboard shortcuts).

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1] - Foundation model with no external dependencies
2. [T2, T3, T4] - All depend only on T1: FindBarView uses FindState API; FocusedKey wraps FindState type; SelectableTextView reads FindState
3. [T5, T6, T7] - Integration tasks that wire everything together
4. [T8] - Unit tests (depends on T1 only, parallelizable with groups 2-3)

**Dependencies**:

- T2 -> T1 (interface: FindBarView reads/writes FindState properties and calls its methods)
- T3 -> T1 (interface: FocusedValueKey wraps the FindState type)
- T4 -> T1 (interface: Coordinator reads FindState and calls performSearch)
- T5 -> [T1, T2] (build: ContentView imports FindBarView and reads FindState.isVisible)
- T6 -> [T1, T3] (build: MkdnCommands uses FocusedFindStateKey to access FindState)
- T7 -> [T1, T3] (build: DocumentWindow creates FindState and publishes via FocusedFindStateKey)
- T8 -> T1 (test: Unit tests exercise FindState directly)

**Critical Path**: T1 -> T4 -> T5 (or equivalently T1 -> T2 -> T5)

## Task Breakdown

### Foundation

- [x] **T1**: Create FindState observable model with search, navigation, and lifecycle logic `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/ViewModels/FindState.swift`
    - **Approach**: Created @MainActor @Observable final class with query/visibility/match state, case-insensitive search via Swift String.range(of:options:range:), wrap-around navigation, and lifecycle methods (show/dismiss/useSelection). Used native Swift String range finding instead of NSString bridge to satisfy SwiftLint legacy_objc_type rule.
    - **Deviations**: Used `String.range(of:options:range:)` instead of `NSString.range(of:options:range:)` to avoid SwiftLint legacy_objc_type violation; functionally equivalent.
    - **Tests**: Deferred to T8

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

    **Reference**: [design.md#31-findstate-model](design.md#31-findstate-model)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Features/Viewer/ViewModels/FindState.swift` with `@MainActor @Observable final class FindState`
    - [x] Properties: `query: String`, `isVisible: Bool`, `currentMatchIndex: Int`, `private(set) matchRanges: [NSRange]`
    - [x] Computed property `matchCount` returns `matchRanges.count`
    - [x] `nextMatch()` wraps forward: `(currentMatchIndex + 1) % matchCount`, no-op when matchCount is 0
    - [x] `previousMatch()` wraps backward: `(currentMatchIndex - 1 + matchCount) % matchCount`, no-op when matchCount is 0
    - [x] `show()` sets `isVisible = true`
    - [x] `dismiss()` clears query, matchRanges, currentMatchIndex, and sets isVisible to false
    - [x] `useSelection(_ text: String)` sets `isVisible = true` and `query = text`
    - [x] `performSearch(in text: String)` performs case-insensitive search using `NSString.range(of:options:range:)` loop, updates matchRanges, clamps currentMatchIndex
    - [x] Empty query produces empty matchRanges
    - [x] currentMatchIndex is clamped when matchRanges shrinks

### Parallel Components

- [x] **T2**: Build FindBarView SwiftUI pill UI with text field, match count, navigation buttons, and animations `[complexity:medium]`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/FindBarView.swift`
    - **Approach**: Created SwiftUI pill view with HStack layout containing magnifyingglass icon, plain TextField bound via @Bindable, conditional match count label, chevron prev/next buttons, and xmark close button. Uses .ultraThinMaterial + Capsule clip, 300pt fixed width, top-right alignment. Keyboard: .onKeyPress for Shift+Return (previousMatch) and Escape (dismiss), .onSubmit for Return (nextMatch). @FocusState toggled on isVisible change. Dismiss wraps findState.dismiss() in withAnimation(quickFade) via MotionPreference.
    - **Deviations**: None
    - **Tests**: N/A (pure SwiftUI view; FindState logic tested in T8)

    **Reference**: [design.md#32-findbarview](design.md#32-findbarview)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] New file `mkdn/Features/Viewer/Views/FindBarView.swift`
    - [x] Pill layout (left to right): magnifyingglass icon, TextField bound to `findState.query`, match count label, chevron.left button, chevron.right button, xmark button
    - [x] Container is approximately 300pt fixed width with Capsule clip and `.ultraThinMaterial` background
    - [x] Match count shows "{current + 1} of {total}" when matches exist, "No matches" when query is non-empty with zero matches, hidden when query is empty
    - [x] Prev/Next buttons call `findState.previousMatch()` / `findState.nextMatch()`
    - [x] Close button calls `findState.dismiss()`
    - [x] Positioned top-right via `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)` with padding
    - [x] Return key calls `findState.nextMatch()`, Shift+Return calls `findState.previousMatch()` via `.onSubmit` and `.onKeyPress`
    - [x] Escape key calls `findState.dismiss()` via `.onKeyPress`
    - [x] `@FocusState` on TextField, toggled true when `isVisible` becomes true
    - [x] Icons and text use `.secondary` foreground style
    - [x] Legible against both Solarized Dark and Solarized Light themes

- [ ] **T3**: Create FocusedFindStateKey for menu command access to per-window FindState `[complexity:simple]`

    **Reference**: [design.md#33-focusedfindstatekey](design.md#33-focusedfindstatekey)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [ ] New file `mkdn/App/FocusedFindStateKey.swift` parallel to existing `FocusedDocumentStateKey.swift`
    - [ ] `struct FocusedFindStateKey: FocusedValueKey` with `typealias Value = FindState`
    - [ ] `FocusedValues` extension with `var findState: FindState?` computed property
    - [ ] Compiles and follows the same pattern as the existing FocusedDocumentStateKey

- [ ] **T4**: Integrate find highlighting and scroll-to-match into SelectableTextView Coordinator and wire MarkdownPreviewView `[complexity:complex]`

    **Reference**: [design.md#34-selectabletextview-modifications](design.md#34-selectabletextview-modifications)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [ ] SelectableTextView gains new parameters: `findQuery: String`, `findCurrentIndex: Int`, `findIsVisible: Bool`, `findState: FindState`
    - [ ] Coordinator gains tracked state: `lastFindQuery`, `lastFindIndex`, `lastFindVisible`, `lastHighlightedRanges`
    - [ ] Coordinator method `applyFindHighlights` performs search via `findState.performSearch(in:)` when query or content has changed
    - [ ] Non-current matches highlighted with theme accent color at 0.15 alpha via TextKit 2 `setRenderingAttributes`
    - [ ] Current match highlighted with theme accent color at 0.4 alpha via TextKit 2 `setRenderingAttributes`
    - [ ] Previous highlights cleared before applying new ones
    - [ ] Current match scrolled into view via `scrollRangeToVisible`
    - [ ] Coordinator method `clearFindHighlights` removes all rendering attributes for previous match ranges
    - [ ] `updateNSView` calls `applyFindHighlights` when find is visible and query/index/content changed, calls `clearFindHighlights` when find becomes not visible
    - [ ] Remove `textView.usesFindBar = true` and `textView.isIncrementalSearchingEnabled = true` from `configureTextView()` to disable stock NSTextFinder
    - [ ] When `findIsVisible` transitions to false, Coordinator calls `textView.window?.makeFirstResponder(textView)` to return focus
    - [ ] Theme changes trigger reapplication of highlight rendering attributes with updated accent color
    - [ ] Document content changes while find bar is open recompute matches and reapply highlights
    - [ ] Helper method `textRange(from:contentManager:)` converts `NSRange` to `NSTextRange` for TextKit 2 API
    - [ ] MarkdownPreviewView reads `@Environment(FindState.self)` and passes `findQuery`, `findCurrentIndex`, `findIsVisible`, and `findState` to SelectableTextView (per [design.md#38-markdownpreviewview-modifications](design.md#38-markdownpreviewview-modifications))

### Integration

- [ ] **T5**: Add FindBarView overlay to ContentView at highest z-order `[complexity:simple]`

    **Reference**: [design.md#35-contentview-modifications](design.md#35-contentview-modifications)

    **Effort**: 1.5 hours

    **Acceptance Criteria**:

    - [ ] FindBarView conditionally rendered inside existing ZStack when `findState.isVisible` is true
    - [ ] FindBarView is the last (highest z-order) element in the ZStack, above TheOrbView and ModeTransitionOverlay
    - [ ] Entrance transition: `.scale(scale: 0.95).combined(with: .opacity)` using springSettle animation
    - [ ] Exit transition: `.opacity` using quickFade animation
    - [ ] Under Reduce Motion, transitions use reducedInstant timing via MotionPreference
    - [ ] Find bar renders above Mermaid diagram overlays, table overlays, code block copy buttons, and mode transition overlay
    - [ ] Find bar maintains position when user scrolls the document

- [ ] **T6**: Replace MkdnCommands find actions with FindState dispatch via FocusedValue `[complexity:medium]`

    **Reference**: [design.md#36-mkdncommands-modifications](design.md#36-mkdncommands-modifications)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] MkdnCommands declares `@FocusedValue(\.findState) private var findState`
    - [ ] Cmd+F calls `findState?.show()` wrapped in `withAnimation(motionAnimation(.springSettle))`
    - [ ] Cmd+G calls `findState?.nextMatch()`
    - [ ] Cmd+Shift+G calls `findState?.previousMatch()`
    - [ ] Cmd+E reads selected text from text view, calls `findState?.useSelection(selectedText)` wrapped in `withAnimation(motionAnimation(.springSettle))`
    - [ ] Previous `sendFindAction` method and `performFindPanelAction` calls are removed entirely
    - [ ] Private `motionAnimation` helper resolves MotionPreference from `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`

- [ ] **T7**: Create and inject FindState in DocumentWindow via environment and focusedSceneValue `[complexity:simple]`

    **Reference**: [design.md#37-documentwindow-modifications](design.md#37-documentwindow-modifications)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [ ] DocumentWindow declares `@State private var findState = FindState()`
    - [ ] ContentView receives FindState via `.environment(findState)`
    - [ ] FindState published via `.focusedSceneValue(\.findState, findState)` for menu command access
    - [ ] FindState injection is parallel to existing DocumentState and AppSettings injection

### Testing

- [ ] **T8**: Write FindState unit tests covering search, navigation, and lifecycle `[complexity:medium]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [ ] New file `mkdnTests/Unit/FindStateTests.swift` using Swift Testing (`@Suite`, `@Test`, `#expect`)
    - [ ] Test: empty query produces no matches
    - [ ] Test: case-insensitive search finds matches regardless of case
    - [ ] Test: multiple matches found with correct ranges
    - [ ] Test: navigation wraps forward from last match to first
    - [ ] Test: navigation wraps backward from first match to last
    - [ ] Test: `dismiss()` clears query, matchRanges, currentMatchIndex, and isVisible
    - [ ] Test: `useSelection` sets query and shows bar
    - [ ] Test: content change recomputes matches (call `performSearch` with different text)
    - [ ] Test: currentMatchIndex clamped when match count decreases
    - [ ] All test functions annotated with `@MainActor` (not the `@Suite` struct)
    - [ ] Tests import `@testable import mkdnLib`

### User Docs

- [ ] **TD1**: Update modules.md Features Layer - Viewer section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Features Layer > Viewer

    **KB Source**: modules.md:Features Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] FindState.swift added to Viewer ViewModels inventory
    - [ ] FindBarView.swift added to Viewer Views inventory

- [ ] **TD2**: Update modules.md App Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: App Layer

    **KB Source**: modules.md:App Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] FocusedFindStateKey.swift added to App layer file inventory
    - [ ] MkdnCommands description updated to reflect FindState dispatch (replacing NSTextFinder)

- [ ] **TD3**: Update architecture.md System Overview `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: System Overview

    **KB Source**: architecture.md:System Overview

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] FindState listed in the per-window state tree alongside DocumentState and AppSettings

- [ ] **TD4**: Update architecture.md Data Flow `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Data Flow

    **KB Source**: architecture.md:Data Flow

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Find bar data flow described: user input -> FindState -> Coordinator search -> highlight rendering -> scroll-to-match

- [ ] **TD5**: Verify index.md Quick Reference coverage `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: index.md:Quick Reference

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Confirm existing paths cover the new feature directories (no change needed per design.md assessment; verify and document confirmation)

## Acceptance Criteria Checklist

### FR-01: Find Bar Activation
- [ ] AC-01a: Pressing Cmd+F when the find bar is hidden shows the find bar and focuses the text input
- [ ] AC-01b: Pressing Cmd+F when the find bar is visible moves keyboard focus to the text input field
- [ ] AC-01c: The find bar appears with the entrance animation (scale + fade from 0.95/0 to 1.0/1.0 using springSettle)
- [ ] AC-01d: Under Reduce Motion, the find bar appears with reducedInstant timing instead of springSettle

### FR-02: Find Bar Dismissal
- [ ] AC-02a: Pressing Escape when the find bar is focused dismisses the find bar
- [ ] AC-02b: Clicking the X close button within the pill dismisses the find bar
- [ ] AC-02c: Dismissal uses quickFade exit animation
- [ ] AC-02d: Under Reduce Motion, dismissal uses reducedInstant timing
- [ ] AC-02e: All match highlights are removed from the text view upon dismissal
- [ ] AC-02f: Keyboard focus returns to the text view after dismissal

### FR-03: Live Incremental Search
- [ ] AC-03a: Each keystroke triggers a search of the full document text for the current query
- [ ] AC-03b: All matches are highlighted in the text view with the subtle tint (accent color at 0.15 alpha)
- [ ] AC-03c: The first match is highlighted with the stronger accent highlight (accent color at 0.4 alpha)
- [ ] AC-03d: The match count display updates to show "1 of N" where N is the total match count
- [ ] AC-03e: If the query produces zero matches, the match count area indicates no matches
- [ ] AC-03f: Clearing the text input removes all highlights and resets the match count
- [ ] AC-03g: Search is case-insensitive

### FR-04: Match Navigation
- [ ] AC-04a: Cmd+G advances to the next match
- [ ] AC-04b: Cmd+Shift+G returns to the previous match
- [ ] AC-04c: Return (when find bar is focused) advances to the next match
- [ ] AC-04d: Shift+Return (when find bar is focused) returns to the previous match
- [ ] AC-04e: Navigation wraps around in both directions
- [ ] AC-04f: The current match index in the "N of M" display updates after each navigation
- [ ] AC-04g: The text view scrolls to make the current match visible using scrollRangeToVisible
- [ ] AC-04h: Previous current match reverts to subtle tint and new current match receives stronger accent

### FR-05: Use Selection for Find
- [ ] AC-05a: Pressing Cmd+E with a text selection populates the find bar's text input with the selected text
- [ ] AC-05b: If the find bar is not visible, Cmd+E shows the find bar with the selection as the query
- [ ] AC-05c: A search is triggered immediately using the populated text
- [ ] AC-05d: If no text is selected, Cmd+E has no effect

### FR-06: Match Count Display
- [ ] AC-06a: When matches exist, the display shows "{current} of {total}"
- [ ] AC-06b: When no matches exist for a non-empty query, the display clearly indicates zero matches
- [ ] AC-06c: When the text input is empty, the match count area is absent or blank
- [ ] AC-06d: The count updates immediately when the query changes or navigation occurs

### FR-07: Find Bar Visual Design
- [ ] AC-07a: The find bar is pill-shaped (fully rounded corners)
- [ ] AC-07b: The find bar is approximately 300pt wide (fixed)
- [ ] AC-07c: The find bar is positioned in the top-right corner of the preview viewport
- [ ] AC-07d: The background uses `.ultraThinMaterial`
- [ ] AC-07e: The find bar is legible against both Solarized Dark and Solarized Light themes

### FR-08: Z-Order
- [ ] AC-08a: The find bar renders above Mermaid diagram overlays
- [ ] AC-08b: The find bar renders above table overlays and sticky table headers
- [ ] AC-08c: The find bar renders above code block copy buttons
- [ ] AC-08d: The find bar renders above the mode transition overlay
- [ ] AC-08e: The find bar maintains its position when the user scrolls the document

### FR-09: Match Highlighting
- [ ] AC-09a: Non-current matches are highlighted with the theme's accent color at 0.15 alpha
- [ ] AC-09b: The current match is highlighted with the theme's accent color at 0.4 alpha
- [ ] AC-09c: Highlights update immediately when the theme changes
- [ ] AC-09d: Highlights are removed when the find bar is dismissed
- [ ] AC-09e: Highlights are removed when the text input is cleared

### FR-10: Animation
- [ ] AC-10a: Entrance animation starts from 0.95 scale and 0.0 opacity, settling to 1.0/1.0
- [ ] AC-10b: Entrance uses the springSettle animation primitive
- [ ] AC-10c: Exit uses the quickFade animation primitive
- [ ] AC-10d: Under Reduce Motion, entrance and exit use reducedInstant
- [ ] AC-10e: MotionPreference resolved via standard accessibility pattern

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] Docs updated
