# Worklog: Document Outline Navigator

## Revision History (Quick Reference)

| Round | Date | Key Change | Confidence |
|-------|------|-----------|------------|
| R1 | 2026-03-21 | Initial research and spec drafts | High |
| R2 | 2026-03-21 | All questions answered; specs updated to Pending Verification | High |
| R3 | 2026-03-21 | A1 and A2 resolved via codebase research; all assumptions now resolved | High |
| R4 | 2026-03-21 | Added comprehension-mode user stories and goals to PRD | VERIFIED |

## Round 1 -- Initial Research

### What I found

**Heading data is already available.** `MarkdownBlock.heading(level:text:)` cases exist in every `[IndexedBlock]` array produced by `MarkdownRenderer.render()`. The `IndexedBlock.index` provides a sequential position that can be mapped to scroll positions via the text layout manager. No new parsing is needed.

**The FindBar provides a complete overlay pattern.** `FindBarView` + `FindState` demonstrate exactly how mkdn integrates overlay UI: `@Observable` state class created in `DocumentWindow`, injected via `.environment()`, published via `.focusedSceneValue()`, view placed in `ContentView`'s ZStack with `.allowsHitTesting()` and `.accessibilityHidden()` guards. The outline navigator should follow this pattern verbatim.

**Scroll observation requires AppKit integration.** The macOS path uses `NSScrollView` with an `NSTextView` document view. Scroll-spy must observe `NSView.boundsDidChangeNotification` on the clip view and map the y-offset to a heading block index via the text layout manager (`NSTextLayoutManager`). This is standard AppKit but requires careful integration with the existing `SelectableTextView.Coordinator`.

**No existing scroll-to-block mechanism for macOS.** `BlockScrollTarget` exists but is only consumed by the Platform/iOS `MarkdownContentView` (via `ScrollViewReader`). For macOS, we need to implement scroll-to-heading using `NSTextView.scrollRangeToVisible()` or by computing the rect from the layout manager and calling `scrollView.contentView.scroll(to:)`.

**Animation primitives are sufficient.** `springSettle` matches the breadcrumb-to-HUD expand animation. `fadeIn`/`fadeOut` work for breadcrumb visibility. `MotionPreference` provides Reduce Motion alternatives automatically.

### My reasoning

**Classification: Consumer-Facing.** This is a user-visible navigation feature with clear UX touchpoints (breadcrumb bar, HUD overlay, keyboard shortcuts). Wrote a PRD + architecture doc.

**Single component, two states (not two views).** The context document explicitly states the breadcrumb IS the HUD in collapsed form. I designed `OutlineNavigatorView` as one view that transitions between states, with `OutlineBreadcrumbBar` as a subview extracted for clarity. The animation connects them spatially.

**Scroll-spy in the Coordinator.** The Coordinator already has a reference to the text view and is the natural place to observe scroll events. Adding a `boundsDidChangeNotification` observer there is minimally invasive. The alternative (a separate scroll observer view) would be more complex and less natural.

**HeadingTreeBuilder as stateless enum.** Follows the project's pattern for computation units (MarkdownRenderer, SyntaxHighlightEngine, etc.). Pure function: blocks in, tree out.

**Fuzzy filter as computed property.** `filteredHeadings` is derived from `flatHeadings` + `filterQuery`. Making it computed avoids stale state and keeps the filter logic simple. Performance is fine for <100 headings.

### Questions I'm asking and why

- Q1: Scroll-to-heading mechanism -- The macOS path has no existing programmatic scroll-to-block. I need to confirm the approach: use text layout manager to find the character range of the heading, then scroll to its rect. This works but the Coordinator needs the blocks array (or at least the heading positions) to map block indices to character ranges.

- Q2: Breadcrumb click behavior -- Should clicking the breadcrumb bar (not a specific segment) open the HUD? This is a UX decision that affects the view design.

- Q3: Empty document behavior -- What happens when Cmd+J is pressed on a document with no headings? Disable the menu item? Show a brief "No headings" message?

### Assumptions Register

| ID | Assumption | Status | Resolution |
|----|-----------|--------|------------|
| A1 | NSTextLayoutManager can provide y-coordinates for heading character ranges to enable scroll-spy | accepted-risk | Standard TextKit 2 API; verified in Apple docs but not tested in this specific codebase. Will validate in Phase 3. |
| A2 | `scrollRangeToVisible()` or equivalent works for scrolling to heading positions in the custom NSTextView setup | accepted-risk | Standard NSTextView method. The custom `CodeBlockBackgroundTextView` subclass should inherit this. Validate in Phase 4. |
| A3 | Fuzzy string matching can be done with a simple substring/prefix check initially, upgrading to proper fuzzy matching later | question-asked | See Q4 in questions.md |
| A4 | The breadcrumb bar should be clickable to open the HUD | question-asked | See Q1 in questions.md |
| A5 | Documents with no headings should disable the Cmd+J shortcut | question-asked | See Q2 in questions.md |

### What to do next

After the user answers the questions, the next agent should:

1. **If A4 resolved (breadcrumb click):** Update `OutlineBreadcrumbBar` design -- either the whole bar opens the HUD on click, or only segments are clickable for jump navigation.

2. **If A5 resolved (empty document):** Update `MkdnCommands` to disable/enable the menu item based on heading count, and update `OutlineNavigatorView` for empty state.

3. **If A3 resolved (fuzzy matching):** Choose between simple `localizedCaseInsensitiveContains` vs a scoring algorithm. This affects the `filteredHeadings` implementation.

4. **Start Phase 1 implementation** (`HeadingNode`, `HeadingTreeBuilder`, tests) -- this is independent of all questions and can proceed immediately.

5. **Prototype the scroll-spy** in Phase 3 to validate assumptions A1 and A2 early.

## Round 2 -- Refinement

### Answers received
- Q1: Click anywhere on breadcrumb opens HUD (no segment-specific clicks) → Impact: Simplified OutlineBreadcrumbBar from multi-button to single-button; removed FR-8's segment navigation; updated Flow 4
- Q2: Disable Cmd+J menu item when no headings → Impact: Added `.disabled()` modifier to MkdnCommands; added FR-22
- Q3: Auto-scroll HUD to current heading on open → Impact: Added FR-21; updated OutlineState.showHUD() to set selectedIndex to current heading
- Q4: Full fzf-style fuzzy matching → Impact: Updated FR-16 with explicit matching semantics; updated OutlineState design notes with scoring approach

### Changes made
- prd.md: Updated FR-8 (breadcrumb click opens HUD, not segment navigation); updated FR-16 (explicit fzf-style matching); added FR-21 (auto-scroll to current heading) and FR-22 (disable Cmd+J when no headings); renumbered FR-21..26 to FR-23..28; updated UX section for breadcrumb click behavior; replaced Open Questions with Resolved Questions section; status changed to Pending Verification
- architecture.md: Updated OutlineBreadcrumbBar design (single click target); updated OutlineState notes (fuzzy matching semantics, showHUD auto-scroll behavior); added .disabled() to MkdnCommands code; updated Flow 4 (breadcrumb click opens HUD); updated error handling table; added auto-scroll test case; status changed to Pending Verification

### Assumptions Register Update

| ID | Assumption | Status | Resolution |
|----|-----------|--------|------------|
| A1 | NSTextLayoutManager can provide y-coordinates for heading character ranges to enable scroll-spy | **resolved** (R3) | Proven in codebase via `OverlayCoordinator` fragment enumeration pattern. See [A1 evidence](../research/a1-layout-manager-y-coordinates.md). |
| A2 | `scrollRangeToVisible()` or equivalent works for scrolling to heading positions | **resolved** (R3) | Both approaches proven in codebase. See [A2 evidence](../research/a2-programmatic-scroll-to-heading.md). |
| A3 | Fuzzy matching approach | resolved | User confirmed fzf-style matching (Q4) |
| A4 | Breadcrumb bar click behavior | resolved | User confirmed whole bar opens HUD (Q1) |
| A5 | No-headings behavior | resolved | User confirmed disable menu item (Q2) |
| A6 | Auto-scroll HUD to current heading | resolved | User confirmed yes (Q3) |

### My reasoning
- Q1 answer simplifies the breadcrumb bar significantly -- one tap target instead of multiple buttons with different behaviors. This also means we don't need segment-specific click handling, which removes a category of edge cases (what if the user clicks the chevron separator? what about very long heading text overflow?).
- Q4 answer (fzf-style) is more complex than substring matching but the user clearly wants the power-user experience. For <100 items, a simple sequential-character-match algorithm with basic scoring (consecutive bonus, word-boundary bonus) is sufficient -- no need for a full fzf port.
- All four questions resolved cleanly with no conflicts or follow-up questions needed.

### What to do next
- All questions are resolved. Specs are at Pending Verification status.
- Implementation can proceed with Phase 1 (HeadingNode, HeadingTreeBuilder, tests).
- The fzf-style fuzzy matching (Q4) will need a small utility function -- consider placing it alongside HeadingTreeBuilder or as a standalone `FuzzyMatcher` in Core/.

## Round 3 -- Assumptions Research

### What I found

**A1 RESOLVED: NSTextLayoutManager y-coordinate mapping is proven in the codebase.** The `OverlayCoordinator` already uses `NSTextLayoutManager.enumerateTextLayoutFragments(from:options:)` extensively to map character ranges to y-coordinates via `fragment.layoutFragmentFrame`. The `boundingRect(for:context:)` method in `OverlayCoordinator+TableOverlays.swift` is a complete reference implementation: convert `NSRange` location to `NSTextContentManager` location, enumerate fragments with `.ensuresLayout`, read `layoutFragmentFrame`. The same `boundsDidChangeNotification` observation needed for scroll-spy is already used by `OverlayCoordinator+Observation.swift:observeScrollChanges(on:)`. No new API patterns needed -- scroll-spy can reuse the exact fragment enumeration pattern already in the codebase[^a1-evidence].

**A2 RESOLVED: Both `scrollRangeToVisible()` and direct scroll-to-point work.** `scrollRangeToVisible()` is already used in the Coordinator for find-in-page navigation (`SelectableTextView+Coordinator.swift:199`). The test harness uses `scrollView.contentView.scroll(to:)` + `reflectScrolledClipView()` for absolute y-position scrolling (`TestHarnessHandler+Scroll.swift:39-40`). The `CodeBlockBackgroundTextView` subclass inherits NSTextView without overriding scroll methods. For outline navigation, Approach 2 (layout fragment y-coordinate + `scroll(to:)`) is preferred because it positions the heading at the viewport top, matching user expectations[^a2-evidence].

### Implementation detail discovered

The heading character ranges are not currently tracked during `MarkdownTextStorageBuilder.build()`. For scroll-spy, we need to know where each heading starts in the final `NSAttributedString`. Options:
1. Record `result.length` before each `appendHeading` call during the build step, returning a `[blockIndex: NSRange]` map.
2. Search the text storage at runtime for heading font attributes.
3. Use the `IndexedBlock.index` to identify which block is a heading, and walk the attributed string block-by-block to find character positions.

Option 1 is cleanest and most performant. It requires a minor addition to `MarkdownTextStorageBuilder` to return heading ranges alongside the `TextStorageResult`.

### Assumptions Register Update

| ID | Assumption | Status | Resolution |
|----|-----------|--------|------------|
| A1 | NSTextLayoutManager can provide y-coordinates for heading character ranges to enable scroll-spy | **resolved** | Proven in codebase: `OverlayCoordinator` uses `enumerateTextLayoutFragments` + `layoutFragmentFrame` for identical purpose. See [A1 evidence](../research/a1-layout-manager-y-coordinates.md). |
| A2 | `scrollRangeToVisible()` or equivalent works for scrolling to heading positions | **resolved** | Both `scrollRangeToVisible()` (find-in-page) and `scroll(to:)` (test harness) are proven in codebase. Recommend `scroll(to:)` for heading-at-top positioning. See [A2 evidence](../research/a2-programmatic-scroll-to-heading.md). |
| A3 | Fuzzy matching approach | resolved | User confirmed fzf-style matching (Q4) |
| A4 | Breadcrumb bar click behavior | resolved | User confirmed whole bar opens HUD (Q1) |
| A5 | No-headings behavior | resolved | User confirmed disable menu item (Q2) |
| A6 | Auto-scroll HUD to current heading | resolved | User confirmed yes (Q3) |

### What to do next
- All assumptions are now resolved. No remaining accepted-risk items.
- Implementation can proceed with full confidence in the scroll-spy and scroll-to-heading approaches.
- Minor addition needed to `MarkdownTextStorageBuilder` to emit heading character ranges (option 1 above).

[^a1-evidence]: [A1: NSTextLayoutManager Y-Coordinate Mapping](../research/a1-layout-manager-y-coordinates.md)
[^a2-evidence]: [A2: Programmatic Scrolling to Heading Positions](../research/a2-programmatic-scroll-to-heading.md)

## Round 4 -- Revision

### Trigger
User review feedback: the PRD's user stories and goals only capture the navigation use case (jumping to sections). The outline also serves a comprehension use case — understanding the overall shape and organization of a document at a glance, without needing to navigate anywhere.

### New learnings validated
- PRD missing comprehension-mode user stories → VERIFIED (user feedback is authoritative; the gap is real — no existing user story or goal addresses "understanding document structure")

### Changes made
- prd.md: Added "comprehension at a glance" as a primary goal; added user stories 7 (unfamiliar document structure overview) and 8 (reviewing document organization); added success metric 6 (HUD readable as structural overview); status changed to Pending Verification
- architecture.md: Updated overview to state dual purpose (navigation + comprehension); added comprehension-focused visual verification step (step 4); status changed to Pending Verification
- context.md: Marked comprehension-mode learning as VERIFIED; updated Motivation in Current Understanding to describe the dual-purpose nature

### Assumptions Register Update

| ID | Assumption | Status | Resolution |
|----|-----------|--------|------------|
| A1-A6 | (unchanged) | resolved | See R2/R3 |

No new assumptions introduced. The comprehension use case does not require new technical capabilities — the existing HUD design (indented heading tree, full document outline) already supports it. The change is in framing and verification criteria, not implementation.

### Impact assessment
- Does this change the overall approach? **No.** The HUD already displays the full heading tree with indentation — it inherently supports comprehension. The change adds explicit user stories, a goal, and a verification step so this use case is not overlooked during implementation and visual testing.
- Which sections were affected? PRD (goals, user stories, success metrics), architecture (overview, visual verification), context (motivation, verification status).
- Are there downstream implications not yet addressed? During visual verification (Phase 5), the tester should now explicitly evaluate whether the heading tree is legible as a structural overview — not just whether navigation works. This may surface design refinements (e.g., level indicators, heading counts, section depth visualization) that are not currently specified.

### What to do next
- Specs are at Pending Verification status. Re-verify if needed.
- Implementation can proceed; no architectural changes required.
- During Phase 5 visual verification, explicitly evaluate comprehension clarity: can a reader glance at the HUD and understand the document's shape?
