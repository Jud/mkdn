# Feature Questions & Decisions: Document Outline Navigator

**Status:** All Answered
**Round:** 1

This document tracks all clarifying questions and their answers.
It serves as the decision record for this feature.

---

## Round 1

### Q1. Should clicking the breadcrumb bar open the outline HUD?

_Why this matters: The breadcrumb bar is the resting state of the navigator. If clicking it opens the HUD, it serves as a discoverable entry point beyond the Cmd+J shortcut. If not, clicks are only for navigating to individual breadcrumb segments._

_Agent's reasoning: The context document says the breadcrumb IS the HUD in collapsed form, which suggests clicking the breadcrumb to expand it is natural. But it could also be confusing if users click expecting to jump to the shown heading and get an expanded HUD instead. The design could support both: clicking a specific segment jumps to that heading, clicking the bar background or a dedicated expand affordance opens the HUD._

**Answer:** Click anywhere on the breadcrumb opens the HUD. No distinction between segment clicks and background clicks — the whole breadcrumb is a single tap target that expands into the outline.

### Q2. What should happen when Cmd+J is pressed and the document has no headings?

_Why this matters: Source code files, plain text files, and very short Markdown files may have zero headings. The feature needs a defined behavior for this case._

_Agent's reasoning: Options are (a) disable the Cmd+J menu item when no headings exist, (b) show a brief "No headings" message in the HUD position, or (c) do nothing. Option (a) follows the pattern used by other menu items (e.g., Save is disabled when no unsaved changes). Option (b) gives feedback but adds visual complexity. I lean toward (a) for simplicity._

**Answer:** Disable the Cmd+J menu item when the document has no headings. Standard Mac behavior, grey it out.

### Q3. Should the outline HUD auto-scroll its internal list to the current heading on open?

_Why this matters: In a document with 30+ headings, the current heading might be far down the list. If the HUD opens scrolled to the top, the user has to scroll within the HUD to find where they are. Auto-scrolling to the current heading provides immediate context._

_Agent's reasoning: Auto-scrolling to the current heading seems clearly correct -- it makes the HUD immediately useful by showing "you are here." The current heading is already highlighted (FR-14), so auto-scrolling to it makes the highlight visible. I'm listing this as a question because it's a UX detail worth confirming, but I've designed the architecture assuming yes._

**Answer:** Yes, auto-scroll the HUD's heading list to highlight the current heading when opened. Essential for long documents with 30+ headings.

### Q4. What level of fuzzy matching is needed for the heading filter?

_Why this matters: "Fuzzy matching" can range from simple case-insensitive substring matching to full fuzzy scoring (character-by-character matching with gap penalties, like fzf). The implementation complexity differs significantly._

_Agent's reasoning: For a feature with typically <50 items, simple case-insensitive substring matching (`localizedCaseInsensitiveContains`) is likely sufficient and much simpler to implement. True fuzzy matching (typing "cmpdsn" to match "Component Design") is powerful but adds complexity. I'd recommend starting with substring matching and upgrading only if real usage demands it._

**Answer:** Fuzzy matching (fzf-style) for the type-to-filter. Characters match in order but not necessarily adjacent. E.g., typing "morch" finds "Migration Orchestrator".
