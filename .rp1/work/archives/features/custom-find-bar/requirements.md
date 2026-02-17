# Requirements Specification: Custom Find Bar

**Feature ID**: custom-find-bar
**Version**: 1.0.0
**Status**: Draft
**Created**: 2026-02-15

## 1. Feature Overview

Replace the stock NSTextFinder find bar with a custom-designed, compact pill-shaped find bar that floats in the top-right corner of the preview viewport. The custom find bar provides live incremental search with match highlighting and navigation, using frosted glass materials and motion-respecting animations consistent with the existing mkdn design language.

## 2. Business Context

### 2.1 Problem Statement

The stock NSTextFinder find bar is visually incongruent with mkdn's carefully crafted Solarized design language. It occupies the full width of the text view, pushes content down, and does not match the frosted glass, spring-settled, and motion-respectful aesthetic that defines the rest of the application. For a daily-driver tool whose charter emphasizes obsessive attention to sensory detail, the find experience must meet the same standard as every other interactive element.

### 2.2 Business Value

- **Design coherence**: Every UI surface in mkdn adheres to the Solarized palette, frosted glass materials, and the animation design language. The find bar is a high-frequency interaction point that currently breaks this consistency.
- **Workflow efficiency**: A compact pill that does not displace content keeps the user's reading context intact while searching.
- **Daily-driver polish**: Find (Cmd+F) is one of the most common keyboard shortcuts for developers reading Markdown artifacts. A polished, native-feeling find bar reinforces the quality perception that drives daily-driver adoption.

### 2.3 Success Metrics

| Metric | Target |
|--------|--------|
| Visual consistency | Find bar uses the same material, accent colors, and animation primitives as existing overlays (e.g., CodeBlockCopyButton, ModeTransitionOverlay) |
| Content preservation | Find bar does not displace, push, or obscure the document content beyond its own ~300pt footprint |
| Match navigation reliability | Every navigable match scrolls into view and is visually distinguishable from other matches |
| Keyboard-only operability | All find operations (open, search, next, previous, dismiss) are fully operable without a mouse |
| Reduce Motion compliance | All find bar animations degrade gracefully under Reduce Motion, with no lost functionality |

## 3. Stakeholders & Users

### 3.1 User Types

| User Type | Description | Relevance |
|-----------|-------------|-----------|
| Developer (primary) | Terminal-oriented developer reading/editing Markdown artifacts. High keyboard fluency. Uses Cmd+F reflexively when scanning long documents | Primary actor for all find bar requirements |

### 3.2 Stakeholder Interests

| Stakeholder | Interest |
|-------------|----------|
| Project creator | Design coherence with charter philosophy; daily-driver polish for the most common keyboard shortcut |

## 4. Scope Definition

### 4.1 In Scope

- Custom pill-shaped find bar UI replacing NSTextFinder visuals
- Live incremental search as the user types
- Match count display in "N of M" format
- Visual highlighting of all matches in the text view
- Distinguished highlighting for the current match vs. other matches
- Keyboard navigation between matches (next/previous)
- "Use selection for find" (Cmd+E)
- Frosted glass material consistent with existing UI surfaces
- Entrance/exit animations using existing named primitives
- Reduce Motion compliance via MotionPreference
- Z-ordering: find bar floats above all other overlays
- Scroll-to-match when navigating between matches

### 4.2 Out of Scope

- Find and replace functionality (this spec covers find-only)
- Regular expression or fuzzy search
- Search history or recent searches list
- Find across multiple open documents
- Find within Mermaid diagram content (rendered in WKWebView)
- Find within image alt text
- Persistent find bar state between sessions
- Custom find bar in the editor pane (side-by-side mode editor)

### 4.3 Assumptions

- The underlying NSTextView (CodeBlockBackgroundTextView / SelectableTextView) provides programmatic text search and range-based highlight capabilities sufficient to support custom match highlighting.
- NSTextView.scrollRangeToVisible provides adequate scroll-to-match behavior without custom scroll animation.
- The existing overlay coordinate system (used by OverlayCoordinator for Mermaid, tables, images) can coexist with a find bar overlay without conflict, since the find bar is positioned in a fixed screen location (top-right) rather than at text attachment positions.

## 5. Functional Requirements

### FR-01: Find Bar Activation (Must Have)

**Actor**: Developer
**Action**: Activate the find bar via Cmd+F keyboard shortcut
**Outcome**: The find bar appears in the top-right corner of the preview viewport with the text input field focused and ready for typing. If the find bar is already visible, Cmd+F re-focuses the text input field.
**Rationale**: Cmd+F is the universal Mac find shortcut. Developers expect instant access with keyboard focus ready for typing.
**Acceptance Criteria**:
- AC-01a: Pressing Cmd+F when the find bar is hidden shows the find bar and focuses the text input
- AC-01b: Pressing Cmd+F when the find bar is visible moves keyboard focus to the text input field
- AC-01c: The find bar appears with the entrance animation (scale + fade from 0.95/0 to 1.0/1.0 using springSettle)
- AC-01d: Under Reduce Motion, the find bar appears with reducedInstant timing instead of springSettle

### FR-02: Find Bar Dismissal (Must Have)

**Actor**: Developer
**Action**: Dismiss the find bar via Escape key or close button
**Outcome**: The find bar disappears, all match highlights are cleared from the text view, and keyboard focus returns to the text view.
**Rationale**: Users need a fast, predictable way to exit find mode and return to reading. Both keyboard and pointer dismissal must be available.
**Acceptance Criteria**:
- AC-02a: Pressing Escape when the find bar is focused dismisses the find bar
- AC-02b: Clicking the X close button within the pill dismisses the find bar
- AC-02c: Dismissal uses quickFade exit animation
- AC-02d: Under Reduce Motion, dismissal uses reducedInstant timing
- AC-02e: All match highlights are removed from the text view upon dismissal
- AC-02f: Keyboard focus returns to the text view after dismissal

### FR-03: Live Incremental Search (Must Have)

**Actor**: Developer
**Action**: Type a search query into the find bar text input
**Outcome**: Matches are found and highlighted in the text view incrementally as each character is typed. The match count updates to reflect the current number of matches. The first match is selected as the current match.
**Rationale**: Incremental search provides immediate visual feedback, helping users find content faster without committing to a full query before seeing results.
**Acceptance Criteria**:
- AC-03a: Each keystroke triggers a search of the full document text for the current query
- AC-03b: All matches are highlighted in the text view with the subtle tint (accent color at 0.15 alpha)
- AC-03c: The first match is highlighted with the stronger accent highlight (accent color at 0.4 alpha)
- AC-03d: The match count display updates to show "1 of N" where N is the total match count
- AC-03e: If the query produces zero matches, the match count area indicates no matches (e.g., "0 of 0" or "No matches")
- AC-03f: Clearing the text input removes all highlights and resets the match count
- AC-03g: Search is case-insensitive

### FR-04: Match Navigation (Must Have)

**Actor**: Developer
**Action**: Navigate between matches using keyboard shortcuts or Return/Shift+Return
**Outcome**: The current match advances (or retreats) to the next (or previous) match, the current match highlight updates, the match count display updates to reflect the new position, and the text view scrolls to make the current match visible.
**Rationale**: Developers scanning long documents need to step through matches sequentially. Multiple shortcut bindings accommodate both muscle memory patterns (Cmd+G from other Mac apps, Return from within the text field).
**Acceptance Criteria**:
- AC-04a: Cmd+G advances to the next match
- AC-04b: Cmd+Shift+G returns to the previous match
- AC-04c: Return (when find bar is focused) advances to the next match
- AC-04d: Shift+Return (when find bar is focused) returns to the previous match
- AC-04e: Navigation wraps around: advancing past the last match returns to the first, retreating past the first match goes to the last
- AC-04f: The current match index in the "N of M" display updates after each navigation
- AC-04g: The text view scrolls to make the current match visible using scrollRangeToVisible
- AC-04h: The previous current match reverts to the subtle tint (0.15 alpha) and the new current match receives the stronger accent (0.4 alpha)

### FR-05: Use Selection for Find (Should Have)

**Actor**: Developer
**Action**: Press Cmd+E with text selected in the text view
**Outcome**: The selected text is placed into the find bar's text input field and a search is triggered. If the find bar is not visible, it becomes visible.
**Rationale**: A standard Mac convention that allows users to quickly search for text they are already looking at without retyping it.
**Acceptance Criteria**:
- AC-05a: Pressing Cmd+E with a text selection populates the find bar's text input with the selected text
- AC-05b: If the find bar is not visible, Cmd+E shows the find bar with the selection as the query
- AC-05c: A search is triggered immediately using the populated text
- AC-05d: If no text is selected, Cmd+E has no effect (or shows the find bar empty, if hidden)

### FR-06: Match Count Display (Must Have)

**Actor**: Developer
**Action**: Observe the match count while searching
**Outcome**: The find bar displays the current match position and total match count in "N of M" format (e.g., "3 of 17").
**Rationale**: Users need to know how many matches exist and where they are in the sequence to orient themselves within search results.
**Acceptance Criteria**:
- AC-06a: When matches exist, the display shows "{current} of {total}" (e.g., "3 of 17")
- AC-06b: When no matches exist for a non-empty query, the display clearly indicates zero matches
- AC-06c: When the text input is empty, the match count area is absent or blank
- AC-06d: The count updates immediately when the query changes or navigation occurs

### FR-07: Find Bar Visual Design (Must Have)

**Actor**: Developer
**Action**: Observe the find bar appearance
**Outcome**: The find bar is a compact pill-shaped element with a fixed width of approximately 300pt, positioned in the top-right corner of the preview viewport, using `.ultraThinMaterial` frosted glass background.
**Rationale**: The pill shape, frosted glass, and compact footprint maintain design coherence with existing overlays (CodeBlockCopyButton uses ultraThinMaterial) and minimize disruption to document reading.
**Acceptance Criteria**:
- AC-07a: The find bar is pill-shaped (fully rounded corners)
- AC-07b: The find bar is approximately 300pt wide (fixed, not responsive)
- AC-07c: The find bar is positioned in the top-right corner of the preview viewport
- AC-07d: The background uses `.ultraThinMaterial`
- AC-07e: The find bar text, icons, and match count are legible against both Solarized Dark and Solarized Light themes

### FR-08: Z-Order (Must Have)

**Actor**: Developer
**Action**: Scroll or interact with document content while the find bar is visible
**Outcome**: The find bar always floats above all other overlays, including Mermaid diagrams, tables, images, code block copy buttons, and the mode transition overlay.
**Rationale**: The find bar must remain accessible and visible at all times while active, regardless of scroll position or overlay content underneath.
**Acceptance Criteria**:
- AC-08a: The find bar renders above Mermaid diagram overlays
- AC-08b: The find bar renders above table overlays and sticky table headers
- AC-08c: The find bar renders above code block copy buttons
- AC-08d: The find bar renders above the mode transition overlay
- AC-08e: The find bar maintains its position when the user scrolls the document

### FR-09: Match Highlighting (Must Have)

**Actor**: Developer
**Action**: Search for text that has multiple matches
**Outcome**: All matches are visually highlighted in the text view. The current match is visually distinct from other matches.
**Rationale**: Users need to see all matches at a glance and clearly identify which match is the current one during navigation.
**Acceptance Criteria**:
- AC-09a: Non-current matches are highlighted with the theme's accent color at 0.15 alpha
- AC-09b: The current match is highlighted with the theme's accent color at 0.4 alpha
- AC-09c: Highlights update immediately when the theme changes (Solarized Dark to Light or vice versa)
- AC-09d: Highlights are removed when the find bar is dismissed
- AC-09e: Highlights are removed when the text input is cleared

### FR-10: Animation (Should Have)

**Actor**: Developer
**Action**: Open or dismiss the find bar
**Outcome**: The find bar entrance uses a scale + fade animation (from 0.95 scale and 0 opacity) with the springSettle primitive. The exit uses the quickFade primitive. Under Reduce Motion, both degrade to reducedInstant timing.
**Rationale**: Consistent use of the animation design language reinforces the sensory coherence of the application. Motion-respectful behavior is a charter-level commitment.
**Acceptance Criteria**:
- AC-10a: Entrance animation starts from 0.95 scale and 0.0 opacity, settling to 1.0 scale and 1.0 opacity
- AC-10b: Entrance uses the springSettle animation primitive
- AC-10c: Exit uses the quickFade animation primitive
- AC-10d: Under Reduce Motion (MotionPreference), entrance and exit use reducedInstant
- AC-10e: MotionPreference is resolved via the standard `@Environment(\.accessibilityReduceMotion)` pattern

## 6. Non-Functional Requirements

### 6.1 Performance Expectations

| Expectation | Target |
|-------------|--------|
| Search responsiveness | Incremental search results appear within a single frame (~16ms) for typical documents (under 10,000 words) |
| Match navigation | Navigating to the next/previous match is instantaneous (no perceptible delay) |
| Find bar appearance | Entrance animation begins within one frame of Cmd+F keypress |

### 6.2 Security Requirements

No security requirements. The find bar operates on locally loaded document text only.

### 6.3 Usability Requirements

| Requirement | Description |
|-------------|-------------|
| Keyboard-complete workflow | All find operations (open, type, navigate, dismiss) must be operable entirely via keyboard |
| Standard Mac conventions | All keyboard shortcuts match standard macOS find conventions (Cmd+F, Cmd+G, Cmd+E, Escape) |
| Reduce Motion | All animations must respect the system Reduce Motion accessibility preference via MotionPreference |
| Theme adaptation | The find bar must be legible and aesthetically appropriate in both Solarized Dark and Solarized Light themes |

### 6.4 Compliance Requirements

No external compliance requirements. Internal compliance with the mkdn animation design language (AnimationConstants, MotionPreference) and theme system (ThemeColors, AppTheme) is required.

## 7. User Stories

### STORY-01: Quick Search

**As a** developer reading a long Markdown document,
**I want** to press Cmd+F and type a search term to see all matches highlighted immediately,
**So that** I can quickly locate specific content without scrolling through the entire document.

**Acceptance Scenarios**:
- GIVEN I am viewing a Markdown document in preview mode, WHEN I press Cmd+F and type "config", THEN all occurrences of "config" are highlighted in the text view and the match count shows the total
- GIVEN I have typed a query with 5 matches, WHEN I press Cmd+G three times, THEN the current match indicator shows "4 of 5" and the fourth match is scrolled into view

### STORY-02: Navigate Matches

**As a** developer scanning search results,
**I want** to step forward and backward through matches with keyboard shortcuts,
**So that** I can review each occurrence in context without losing my place.

**Acceptance Scenarios**:
- GIVEN I have 10 matches and the current match is "3 of 10", WHEN I press Cmd+G, THEN the display shows "4 of 10" and the fourth match scrolls into view with the stronger highlight
- GIVEN I am on match "1 of 10", WHEN I press Cmd+Shift+G, THEN the display shows "10 of 10" (wraps to last)

### STORY-03: Dismiss and Resume Reading

**As a** developer who has finished searching,
**I want** to press Escape to dismiss the find bar and clear all highlights,
**So that** I can return to uncluttered reading with keyboard focus back in the document.

**Acceptance Scenarios**:
- GIVEN the find bar is visible with 7 highlighted matches, WHEN I press Escape, THEN the find bar disappears with a fade animation, all highlights are removed, and I can immediately use arrow keys to scroll the document

### STORY-04: Search from Selection

**As a** developer who sees a term in the document and wants to find other occurrences,
**I want** to select the term and press Cmd+E to search for it,
**So that** I can find all occurrences without retyping the term.

**Acceptance Scenarios**:
- GIVEN I have selected the word "pipeline" in the document, WHEN I press Cmd+E, THEN the find bar appears with "pipeline" in the text input and all occurrences are highlighted

### STORY-05: Find Bar Does Not Disrupt Content

**As a** developer reading near the top of a document,
**I want** the find bar to float over the content without pushing it down,
**So that** my reading position and context are preserved while searching.

**Acceptance Scenarios**:
- GIVEN I am reading the second paragraph of a document, WHEN I press Cmd+F, THEN the content does not shift or reflow; the find bar floats above the content in the top-right corner

## 8. Business Rules

| Rule ID | Rule |
|---------|------|
| BR-01 | Search is always case-insensitive |
| BR-02 | Match navigation wraps around in both directions (last -> first, first -> last) |
| BR-03 | The find bar must use existing named animation primitives (springSettle, quickFade) -- no ad hoc animation values |
| BR-04 | The find bar must use existing theme colors (accent from ThemeColors) for match highlighting -- no hard-coded colors |
| BR-05 | The find bar must resolve MotionPreference from the system accessibility setting -- no separate motion toggle |
| BR-06 | The find bar operates only on the rendered preview text view, not on Mermaid WKWebView content or image content |

## 9. Dependencies & Constraints

| Dependency / Constraint | Type | Impact |
|-------------------------|------|--------|
| ThemeColors.accent | Existing system | Highlight colors derive from the theme accent color |
| AnimationConstants (springSettle, quickFade) | Existing system | Entrance and exit animations must use these primitives |
| MotionPreference | Existing system | Reduce Motion compliance must use this resolver |
| .ultraThinMaterial | SwiftUI API | Frosted glass background |
| NSTextView / TextKit 2 | Existing system | Underlying text view must support programmatic search and range-based highlighting |
| SelectableTextView / CodeBlockBackgroundTextView | Existing component | The find bar must integrate with or overlay the existing text view infrastructure |
| OverlayCoordinator | Existing component | The find bar must coexist with existing overlay management without conflict |
| macOS 14.0+ | Platform constraint | All APIs used must be available on macOS 14.0 (Sonoma) or later |

## 10. Clarifications Log

| # | Question | Answer | Source |
|---|----------|--------|--------|
| 1 | PRD association? | Standalone feature, no parent PRD | User clarification |
| 2 | Compact pill dimensions? | Fixed ~300pt width | User clarification |
| 3 | Match count display format? | "3 of 17" style (N of M) | User clarification |
| 4 | Dismiss behavior? | Escape key + X close button within the pill | User clarification |
| 5 | Frosted glass material? | `.ultraThinMaterial` for consistency with existing patterns | User clarification |
| 6 | Highlight color? | Theme accent color. Current match: 0.4 alpha. Other matches: 0.15 alpha | User clarification |
| 7 | Keyboard shortcuts? | Cmd+F (show/focus), Cmd+G / Cmd+Shift+G (next/prev), Cmd+E (use selection), Return/Shift+Return (next/prev within bar) | User clarification |
| 8 | Animation? | springSettle entrance (0.95 scale + 0 opacity), quickFade exit. Respect Reduce Motion via MotionPreference | User clarification |
| 9 | Scroll to match? | NSTextView.scrollRangeToVisible default behavior | User clarification |
| 10 | Z-order? | Find bar always floats above all other overlays | User clarification |

## AFK Mode: Auto-Selected Defaults

| Decision Point | Choice | Rationale |
|----------------|--------|-----------|
| PRD association | No parent PRD (standalone) | User explicitly stated standalone feature |
| Case sensitivity | Case-insensitive search only | Most common default for find bars; no user mention of case-sensitive toggle |
| Find scope | Preview text view only (not editor pane) | User specified "Mac-native Markdown viewer" context; editor find is a separate concern |
| Empty query behavior | No highlights, blank match count | Standard behavior; no special empty-state requirement stated |
| Wrap-around navigation | Enabled by default | Standard Mac find behavior; no user statement to the contrary |

## AFK Mode: Inferred Decisions

| Ambiguity | Resolution | Source |
|-----------|------------|--------|
| Find bar height not specified | Infer standard single-line text field height (~30-36pt); implementation decision | Conservative default |
| Padding/margins for top-right positioning not specified | Infer consistent spacing with existing UI margins; implementation decision | Spatial design language patterns |
| Behavior when document text changes (reload) while find bar is open | Re-execute search with current query, reset to first match if match count changes | Conservative default |
| Find bar behavior in side-by-side edit mode | Find bar operates on the preview pane only (right side) | Charter scope: viewer-focused; editor find is out of scope |
| Highlight rendering mechanism (temporary attributes vs. layout manager) | Implementation decision deferred to design phase | Not a requirements concern (WHAT not HOW) |
| Match count upper bound display (e.g., "99+" for very large counts) | Show exact count regardless of magnitude | Conservative default; no truncation stated |
