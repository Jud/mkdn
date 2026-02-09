# PRD: Spatial Design Language

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.1.0
**Status**: Complete
**Created**: 2026-02-07

## Surface Overview

A spatial design language framework for mkdn that replaces ad-hoc magic numbers with named spacing primitives on an 8pt grid. `SpacingConstants.swift` is the spatial equivalent of `AnimationConstants.swift` -- every spatial relationship in the application derives from named primitives defined in a single enum, each documented with its visual intent, design rationale, and derivation from typographic design philosophy.

The framework grounds mkdn's spatial decisions in the principles of Dieter Rams (less but better), Jan Tschichold (asymmetric typography), Josef Muller-Brockmann (grid systems), Massimo Vignelli (the canon of rational space), Edward Tufte (data-ink ratio / chartjunk elimination), Matthew Butterick (practical typography for screens), Gestalt proximity (spatial grouping implies semantic grouping), and WCAG spacing guidelines.

The framework also establishes absolute spatial control over the window frame itself. mkdn uses `.hiddenTitleBar` with a transparent titlebar and hidden traffic lights, but macOS still imposes a phantom safe area inset at the top (~28pt) that different views handle inconsistently -- some ignore it (content at the literal window top), others respect it (content offset by ~28pt), and one view required a GeometryReader workaround when simple alignment + padding failed. This creates two competing coordinate origins and ad-hoc fixes. The spatial design language eliminates this ambiguity by zeroing the phantom inset at the NSWindow level (or, if that proves unreliable, codifying the workarounds into reusable modifiers). Either way, SpacingConstants owns every pixel from the window frame inward. The distance from window edge to content is a design decision expressed as a named primitive, not a system accommodation.

The goal is a zenlike reading experience where whitespace is not absence but structure -- where the reader's eye flows effortlessly because every spatial decision was made with the same obsessive care as the animation timing.

## Scope

### In Scope

- **8pt grid primitives**: Named spacing constants (4, 8, 12, 16, 24, 32, 48, 64) as `CGFloat` values in a `SpacingConstants` enum
- **Window chrome spacing**: Window-edge insets that replace the system safe area, scroll-behind behavior for the top zone, and the root `.ignoresSafeArea()` convention
- **Layout spacing**: Document margins, block-to-block spacing, component internal padding, content width constraints
- **Typography spacing**: Line-height multipliers, paragraph spacing, heading margins (above/below with Gestalt proximity asymmetry)
- **List spacing**: Item spacing, nested indentation, bullet/number gutter width
- **Structural rules**: Documented invariants (internal <= external, named primitives only, design rationale per value)
- **Design philosophy documentation**: Each primitive traces back to its typographic tradition in doc comments, following the AnimationConstants documentation pattern (visual intent, design rationale, derivation)

### Out of Scope

- **Responsive spacing**: No dynamic spacing that adapts to window size (future PRD)
- **Animation-related spacing**: Motion offsets and entrance drift values remain in `AnimationConstants`
- **Call-site migration**: Replacing existing hardcoded values in views with `SpacingConstants` references is a separate implementation task (though this PRD documents what the target state looks like)
- **Theme-varying spacing**: Spacing values are theme-independent (same spatial language across Solarized Dark/Light)

## Requirements

### Functional Requirements

#### FR-1: 8pt Grid Primitives

Named spacing primitives on the 8pt grid, following the `AnimationConstants` pattern (enum with static lets, MARK-delimited groups):

| Primitive | Value | Role | Design Grounding |
|-----------|-------|------|------------------|
| `micro` | 4pt | Sub-grid half-step for optical adjustments | Tschichold: optical correction is not deviation from the grid but its refinement |
| `compact` | 8pt | Tight internal spacing (list items, inline elements) | Base grid unit; Muller-Brockmann grid module |
| `cozy` | 12pt | Component internal padding (code blocks, blockquotes) | 1.5x base; Butterick's minimum comfortable padding for boxed elements |
| `standard` | 16pt | Block-to-block spacing, nested indentation base | 2x base; Vignelli's canonical text block separation |
| `relaxed` | 24pt | Section separation, generous internal padding | 3x base; Tufte's preferred margin for content grouping |
| `spacious` | 32pt | Document margins, major section breaks | 4x base; Tschichold's page margin proportion |
| `generous` | 48pt | Hero spacing, above H1 | 6x base; Muller-Brockmann's column gutter in grid systems |
| `expansive` | 64pt | Maximum spacing primitive (reserved for extreme separation) | 8x base; ceiling of the spatial scale |

#### FR-2: Document Layout Constants

| Constant | Value | Design Grounding |
|----------|-------|------------------|
| `documentMargin` | 32pt (`spacious`) | Tschichold: margins are not empty space but frames that give content room to breathe |
| `contentMaxWidth` | ~680pt | Butterick: 45-90 characters per line; at body size ~13-15pt, 680pt yields ~65-75 characters, the optimal reading measure |
| `blockSpacing` | 16pt (`standard`) | Muller-Brockmann: consistent vertical rhythm between equal-weight elements |

#### FR-3: Typography Spacing Constants

| Constant | Value | Design Grounding |
|----------|-------|------------------|
| `bodyLineHeight` | 1.4-1.5x font size | Butterick: 120-145% line-height for body text; 1.4-1.5x balances density and readability |
| `paragraphSpacing` | 50-100% of line-height | Tschichold: paragraph separation should be perceptibly more than line spacing but not a full blank line |
| `headingSpaceAbove` (H1) | 48pt (`generous`) | Gestalt proximity: large space above signals new major section |
| `headingSpaceBelow` (H1) | 16pt (`standard`) | Gestalt proximity: heading belongs to what follows, not what precedes -- asymmetric margin creates visual binding |
| `headingSpaceAbove` (H2) | 32pt (`spacious`) | Proportional reduction from H1; still clearly a section break |
| `headingSpaceBelow` (H2) | 12pt (`cozy`) | Tighter binding to following content than H1 |
| `headingSpaceAbove` (H3) | 24pt (`relaxed`) | Sub-section signal; less dramatic than H2 |
| `headingSpaceBelow` (H3) | 8pt (`compact`) | Tight binding; H3 is closely coupled to its content |

#### FR-4: Component Spacing Constants

| Constant | Value | Design Grounding |
|----------|-------|------------------|
| `componentPadding` | 12pt (`cozy`) | Butterick: internal padding for boxed elements (code blocks, blockquotes) needs enough air to not feel cramped but not so much it disconnects content from its frame |
| `listItemSpacing` | 8pt (`compact`) | Gestalt proximity: list items are a tight group; spacing must be less than paragraph spacing to read as a unit |
| `nestedIndent` | 16-24pt (`standard` to `relaxed`) | Rams: indentation should be enough to signal hierarchy without wasting horizontal space; 16pt for shallow nesting, 24pt for deeper levels where distinction matters more |
| `blockquoteBorderPadding` | 12pt (`cozy`) | Internal padding from the blockquote border to content |
| `listGutterWidth` | 24pt (`relaxed`) | Width allocated for bullet/number column, providing consistent alignment |

#### FR-5: Structural Rules (Documented Invariants)

1. **Internal <= External**: Component internal padding must never exceed the spacing between components. A code block's 12pt internal padding is less than the 16pt block spacing surrounding it. This is Tufte's principle: the container should be less prominent than the content it frames.

2. **All primitives named**: No raw numeric literals for spacing in view code. Every spatial value references a `SpacingConstants` member. This parallels the existing `AnimationConstants` rule: "Never use inline `.animation(.easeInOut(duration: 0.3))` -- reference the named constant instead."

3. **Design rationale documented**: Every constant includes a doc comment with visual intent, design rationale, and derivation, following the `AnimationConstants` documentation structure.

4. **Grid-aligned**: All values are multiples of 4pt (the sub-grid unit). The 8pt grid is the primary rhythm; 4pt is permitted only for optical corrections (the `micro` primitive).

5. **Zero safe area convention**: The phantom title bar safe area is eliminated at the source (see FR-6). If Approach A succeeds, no view needs `.ignoresSafeArea()` at all -- standard layout primitives work from the window frame. If Approach B is needed, safe area workarounds are encapsulated in reusable modifiers (e.g., `WindowEdgePositioned`), never applied ad-hoc in individual views.

#### FR-6: Window Chrome Spacing

The app uses `.windowStyle(.hiddenTitleBar)` with `titlebarAppearsTransparent = true` and all traffic light buttons hidden. Despite this, macOS still reports a safe area inset at the top of the window (~28pt). This phantom inset creates real layout problems -- SwiftUI's standard layout primitives (`.frame(alignment:)`, `.padding()`) position content from the safe area boundary, not the window frame. The codebase already shows the consequences:

| View | Approach | Result |
|------|----------|--------|
| `MarkdownPreviewView` | `.ignoresSafeArea()` + `.padding(24)` | Content extends to window frame top |
| `WelcomeView` | No safe area handling | Content offset ~28pt from window top by phantom inset |
| `SplitEditorView` | No safe area handling | Content offset ~28pt from window top |
| `DefaultHandlerHintView` | `GeometryReader` + `.position()` + `.ignoresSafeArea()` | Had to use absolute positioning because simple `.frame(alignment: .topTrailing).padding()` positioned from safe area, not window frame |
| `FileChangeOrbView` | `.frame(alignment: .bottomTrailing)` + `.padding(16)` | Works only because bottom safe area inset is 0 |

The DefaultHandlerHintView case is instructive: the initial implementation tried simple alignment + padding for top-trailing positioning, but the phantom title bar inset pushed the orb ~28pt below the window edge. The fix required `GeometryReader` + `.position()` + `.ignoresSafeArea()` -- a workaround that works but is verbose and ad-hoc. The spatial design language must solve this at the source.

**The App Owns Every Pixel**

The goal is to eliminate the phantom safe area entirely so that standard SwiftUI layout primitives work from the window frame without workarounds. Two approaches, in priority order:

**Approach A: Zero the safe area at the NSWindow level (preferred)**

In `WindowAccessor.configureWindow(_:)`, negate the phantom title bar inset:

```swift
let titlebarHeight = window.frame.height - window.contentLayoutRect.height
if titlebarHeight > 0 {
    window.contentView?.additionalSafeAreaInsets.top = -titlebarHeight
}
```

If this works, the result is transformative: SwiftUI sees zero safe area insets on all edges. `.frame(alignment:)`, `.padding()`, ScrollView content margins -- everything works naturally from the window frame. No `.ignoresSafeArea()` needed anywhere. No GeometryReader workarounds. Every view shares the same coordinate origin by default.

**Approach B: Proven workaround patterns (fallback)**

If Approach A doesn't propagate correctly (SwiftUI may reconstruct safe area from window properties regardless of `additionalSafeAreaInsets`), codify the existing workaround patterns into clean utilities:

- **Scrollable content**: `.ignoresSafeArea()` on ScrollView + content margin/padding for initial offset
- **Floating elements**: GeometryReader + `.position()` + `.ignoresSafeArea()` -- extract into a reusable `WindowEdgePositioned` view modifier
- **Static content**: `.ignoresSafeArea()` + explicit padding from SpacingConstants

**Validation requirement**: Phase 2 must begin with a spike that tests Approach A. If `additionalSafeAreaInsets` successfully zeros the phantom inset for all child layout contexts (verified with a test view using `.frame(alignment: .topTrailing).padding(20)` and confirming it positions 20pt from the actual window corner), adopt Approach A. Otherwise, implement Approach B with the `WindowEdgePositioned` modifier.

**Named window-edge constants** (work with either approach):

| Constant | Value | Design Grounding |
|----------|-------|------------------|
| `windowTopInset` | 32pt (`spacious`) | The top of a chromeless window is pure canvas. 32pt creates the sense of a printed page with a generous top margin -- Tschichold's "head margin" is traditionally the widest of the four margins. This value also provides comfortable clearance from the rounded window corners. |
| `windowSideInset` | 32pt (`spacious`) | Matches `documentMargin`. Side insets frame the content symmetrically with the top. Tschichold: the inner margin and head margin set the rhythm; side margins echo it. |
| `windowBottomInset` | 24pt (`relaxed`) | Tschichold: the foot margin is slightly less than the head margin, creating asymmetry that draws the eye upward toward the content rather than letting it sink. |

**Scroll-behind behavior**: For scrollable content (primarily `MarkdownPreviewView`), the background extends to the window frame edge, but content starts at `windowTopInset`. As the user scrolls, content slides under the top zone -- a polished edge-to-edge effect. The specific SwiftUI API depends on which approach succeeds and the deployment target (`.contentMargins` requires macOS 15+; `.safeAreaInset` works on 14+; worst case, `.padding(.top)` inside the ScrollView works but the padding scrolls away).

**Floating element positioning**: Overlays and floating elements (orb, hints) use named constants from the window frame:

| Element | Positioning | Constants |
|---------|-------------|-----------|
| FileChangeOrbView | Bottom-trailing corner | `windowSideInset` from right, `windowBottomInset` from bottom |
| DefaultHandlerHintView | Top-trailing corner | `windowSideInset` from right, `windowTopInset` from top |

With Approach A, these use simple `.frame(alignment:).padding()`. With Approach B, top-edge elements use the `WindowEdgePositioned` modifier.

### Non-Functional Requirements

- **NFR-1: Single source of truth** -- All spacing values defined in one file (`SpacingConstants.swift` in `mkdn/UI/Theme/`), following the established pattern of `AnimationConstants.swift` in the same directory.
- **NFR-2: Zero runtime cost** -- All values are static lets on an enum (no instances, no computation). Same pattern as `AnimationConstants`.
- **NFR-3: Discoverable via autocomplete** -- Enum namespace (`SpacingConstants.documentMargin`) provides IDE discoverability identical to `AnimationConstants.breathe`.
- **NFR-4: WCAG 1.4.12 compliant** -- Text spacing values must meet WCAG 2.1 Success Criterion 1.4.12 (Text Spacing): line-height >= 1.5x font size, paragraph spacing >= 2x font size, letter-spacing >= 0.12x, word-spacing >= 0.16x. The framework's values meet or exceed these minimums.

## Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| `AnimationConstants.swift` | Pattern template | SpacingConstants follows the identical structural pattern: enum, static lets, MARK groups, doc comment format (visual intent / design rationale / derivation). No code dependency, but strong structural coupling as the established convention. |
| `mkdn/UI/Theme/` directory | Location | SpacingConstants.swift lives alongside AnimationConstants.swift, AppTheme.swift, ThemeColors.swift in the Theme layer. |
| SwiftUI layout system | Platform | All values are `CGFloat` consumed by SwiftUI's `.padding()`, `.spacing`, `.frame()`, `.lineSpacing()` modifiers. No custom layout engine needed. |
| `WindowAccessor.swift` | Consumer (migration) | Primary target for Approach A: add `additionalSafeAreaInsets.top = -titlebarHeight` to `configureWindow(_:)` to zero the phantom safe area. If Approach A fails, no changes needed here. |
| `ContentView.swift` | Consumer (migration) | Replaces hardcoded `.padding(16)` (orb) and `GeometryReader` + `.position(x: width - 20, y: 20)` (hint) with SpacingConstants references. With Approach A, the GeometryReader wrapper is removed entirely. With Approach B, it's replaced by a `WindowEdgePositioned` modifier. |
| `MarkdownPreviewView.swift` | Consumer (migration) | Currently uses `.ignoresSafeArea()` and `.padding(24)`. With Approach A: remove `.ignoresSafeArea()`, replace `.padding(24)` with SpacingConstants-based scroll-behind inset. With Approach B: keep `.ignoresSafeArea()`, replace `.padding(24)` with SpacingConstants. Block VStack `spacing: 12` maps to `SpacingConstants.blockSpacing` (16pt). |
| `WelcomeView.swift` | Consumer (migration) | Currently respects system safe area (no `.ignoresSafeArea()`). With Approach A, the safe area is zeroed so no change needed -- centered content works naturally. With Approach B, may need minor adjustment. |
| `MarkdownBlockView.swift` | Consumer (future) | Primary consumer of spacing constants. Currently uses hardcoded values: `.padding(.vertical, 8)`, `spacing: 8`, `spacing: 4`, `.padding(.leading, 12)`, `.padding(.leading, 4)`, `.padding(12)`, heading top padding `8`/`4`. Migration is out of scope for this PRD but these are the known call sites. |
| `CodeBlockView.swift` | Consumer (future) | Code block internal padding (currently 12pt, maps to `componentPadding`). |

### Constraints

| Constraint | Impact |
|------------|--------|
| **8pt grid alignment** | All values must be multiples of 4pt. No arbitrary values like 5pt, 7pt, or 10pt. The grid is the law. |
| **SwiftLint strict mode** | File must pass all opt-in SwiftLint rules. Doc comments, naming conventions, modifier order all enforced. |
| **SwiftFormat** | File must be formatted by SwiftFormat before commit. |
| **No theme variation** | Spacing is constant across themes. Unlike `ThemeColors` which varies per theme, `SpacingConstants` is singular. This is intentional: spatial rhythm is structural, not decorative. |
| **Value changes on migration** | When call sites are migrated (future task), some current hardcoded values will change (e.g., document margin 24->32, block spacing 12->16). This is by design -- the current values were ad-hoc; the new values are grounded in typographic principles. Visual regression testing will be needed during migration. |
| **macOS safe area behavior** | With `.hiddenTitleBar`, macOS still reports a safe area inset at the top (~28pt). The spatial language dismisses this at the root and replaces it with `windowTopInset` (32pt). The 4pt difference (32 vs ~28) is intentional -- the grid-aligned value provides slightly more breathing room than the system default. If Apple changes the safe area behavior in future macOS versions, the app is unaffected because it owns its own insets. |
| **`.contentMargins` availability** | `.contentMargins(_:_:for:)` requires macOS 15.0+. mkdn targets macOS 14.0+, so the implementation may need a fallback using `.safeAreaInset(edge: .top)` or padded overlay for macOS 14. Alternatively, the minimum target could be raised to 15.0. |
| **Existing anti-pattern carve-out** | `patterns.md` currently says "NO magic numbers in business logic (UI layout constants are acceptable)". After this PRD is implemented, that carve-out should be tightened: UI layout constants should reference SpacingConstants, not be inline literals. |

## Milestones & Timeline

### Phase 1: Define the Spatial Language

**Deliverable**: `SpacingConstants.swift` in `mkdn/UI/Theme/`

- Create the enum with all named primitives (FR-1 through FR-4) plus window chrome constants (FR-6)
- Add MARK-delimited groups: Grid Primitives, Window Chrome, Document Layout, Typography Spacing, Component Spacing
- Document every constant with visual intent, design rationale, and derivation (FR-5, rule 3)
- Write unit tests in `mkdnTests/Unit/UI/SpacingConstantsTests.swift` verifying grid alignment (all values % 4 == 0), structural invariant (internal <= external), value correctness, and window inset ordering (top >= bottom, side == documentMargin)
- Pass SwiftLint and SwiftFormat

**Acceptance criteria**: File exists, compiles, passes all tests, passes lint/format, every constant has a doc comment with the three-part documentation structure. Window chrome constants are present and documented.

### Phase 2: Window Chrome Migration

**Deliverable**: Unified coordinate system -- all views position from the window frame.

**Step 2a: Validation spike**
- In `WindowAccessor.configureWindow(_:)`, add `additionalSafeAreaInsets.top = -titlebarHeight` (calculated from `frame.height - contentLayoutRect.height`)
- Add a temporary test view: a small colored rectangle positioned via `.frame(alignment: .topTrailing).padding(20)` — verify it sits 20pt from the actual window corner, not 20pt + ~28pt
- If it works: Approach A confirmed. Proceed with Step 2b-A.
- If it doesn't: Approach B. Proceed with Step 2b-B.

**Step 2b-A (if Approach A works): Clean migration**
- Keep the `additionalSafeAreaInsets` fix in `WindowAccessor`
- Remove `.ignoresSafeArea()` from `MarkdownPreviewView`
- Remove `GeometryReader` + `.position()` + `.ignoresSafeArea()` wrapper from `DefaultHandlerHintView` in `ContentView` -- replace with `.frame(alignment: .topTrailing).padding(.top, SpacingConstants.windowTopInset).padding(.trailing, SpacingConstants.windowSideInset)`
- Replace `FileChangeOrbView`'s `.padding(16)` with `.padding(.trailing, SpacingConstants.windowSideInset).padding(.bottom, SpacingConstants.windowBottomInset)`
- Replace `MarkdownPreviewView`'s `.padding(24)` with scroll-behind inset using SpacingConstants
- Verify `WelcomeView` renders correctly (centered content should be unaffected)

**Step 2b-B (if Approach A doesn't work): Codify workaround patterns**
- Create a `WindowEdgePositioned` view modifier that encapsulates the GeometryReader + `.position()` + `.ignoresSafeArea()` pattern with named edge constants
- Migrate `DefaultHandlerHintView` positioning to use `WindowEdgePositioned`
- Migrate `FileChangeOrbView` positioning to use `WindowEdgePositioned` (for consistency, even though bottom edge works without it)
- Keep `.ignoresSafeArea()` on `MarkdownPreviewView` but replace `.padding(24)` with SpacingConstants
- Document the pattern and the reason for it in SpacingConstants doc comments

**Acceptance criteria**: All floating elements positioned using SpacingConstants values. All views share the same effective coordinate origin (window frame). No ad-hoc `.ignoresSafeArea()` or magic-number `.position()` calls. The approach (A or B) is documented in SpacingConstants with a brief "why" comment.

### Phase 3: Knowledge Base Update

**Deliverable**: Updated `.rp1/context/` files

- Update `modules.md` to include SpacingConstants in the UI/Theme table
- Update `patterns.md` to add a "Spacing Pattern" section parallel to the "Animation Pattern" section, documenting the usage convention and the tightened anti-pattern rule
- Update `index.md` Quick Reference to include SpacingConstants path

**Acceptance criteria**: Knowledge base accurately reflects the new file and the convention for using it.

## Open Questions

| ID | Question | Impact | Status |
|----|----------|--------|--------|
| OQ-1 | Should `contentMaxWidth` be exactly 680pt or should it be expressed as a range (e.g., 640-720pt) with the specific value chosen at the view level? | Affects whether SpacingConstants prescribes a single value or a min/max pair | Open |
| OQ-2 | Should heading spacing constants use a lookup function (e.g., `SpacingConstants.headingSpaceAbove(level:)`) or individual named constants (e.g., `h1SpaceAbove`, `h2SpaceAbove`)? | API design; function is DRYer, individual constants are more discoverable | Open |
| OQ-3 | The current `MarkdownPreviewView` uses 24pt document margin and 12pt block spacing. The designed values are 32pt and 16pt respectively. Should migration preserve current values as a `legacy` group or go straight to the designed values? | Affects visual continuity during migration | Open |
| OQ-4 | Should scroll-behind behavior use `.contentMargins` (macOS 15+), `.safeAreaInset(edge: .top)` (macOS 14+), or a padded overlay? `.contentMargins` is the most elegant API but requires macOS 15.0+. `.safeAreaInset` works on 14.0+ but creates a true safe area rather than a content margin. | Affects minimum deployment target or implementation complexity | Open |
| OQ-5 | Should `windowTopInset` be 32pt (grid-aligned, generous) or should it be dynamically read from the system's title bar height via `window.frame.height - window.contentLayoutRect.height` and then rounded to the nearest grid value? Note: with Approach A, the phantom safe area is zeroed, so `windowTopInset` is purely a design constant (how much breathing room we want). With Approach B, it could be argued the inset should match the phantom height to avoid double-offsetting. | Static is simpler and matches the design philosophy; dynamic is more defensive. Approach A makes this purely a design question. | Open |

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A-1 | Spacing values are theme-independent (same across Solarized Dark/Light and any future themes) | Would need to restructure SpacingConstants into a per-theme model like ThemeColors, significantly increasing complexity | Design Philosophy: "obsessive attention to sensory detail" -- spatial rhythm is structural, not decorative |
| A-2 | The 8pt grid with 4pt sub-grid provides sufficient granularity for all spacing needs | May encounter cases where optical correction requires non-grid values (e.g., 3pt, 6pt). Would need to either add sub-grid exceptions or accept imperfect alignment | Design Philosophy: visual perfection may occasionally conflict with grid purity |
| A-3 | Typography spacing values (line-height, paragraph spacing) can be expressed as static constants rather than computed from dynamic font size | If mkdn adds user-configurable font sizes, these would need to become multipliers applied at runtime rather than fixed pt values | Scope Guardrails: no mention of configurable font sizes, but not explicitly excluded |
| A-4 | The AnimationConstants documentation pattern (visual intent / design rationale / derivation) translates well to spatial constants | Spatial constants may benefit from a different documentation structure (e.g., including "relationship to neighbors" or "grid derivation"). Can adjust during implementation | N/A -- pattern established by AnimationConstants, adaptable |
| A-5 | `NSWindow.contentView.additionalSafeAreaInsets` with a negative top value can fully cancel the phantom title bar safe area inset for all SwiftUI child views (Approach A) | SwiftUI may reconstruct safe area from window properties regardless of `additionalSafeAreaInsets`. The DefaultHandlerHintView experience (where `.frame(alignment:).padding()` didn't position from the window frame) suggests SwiftUI's safe area behavior with `.hiddenTitleBar` is unreliable. Mitigation: validation spike (Phase 2a) tests this before committing. Approach B provides a proven fallback. | Architecture: single coordinate system for all views |
| A-6 | `.contentMargins` (or `.safeAreaInset`) on a ScrollView creates the scroll-behind effect where content slides under the top zone during scroll | If the implementation doesn't produce the desired visual effect, fallback to a simple `.padding(.top, windowTopInset)` inside the ScrollView (current pattern, less polished) | Design Philosophy: "obsessive attention to sensory detail" |
| R-1 | Visual regression on migration: changing document margin from 24pt to 32pt and block spacing from 12pt to 16pt will noticeably alter the reading experience | Users (the creator) may prefer the current tighter spacing. Mitigation: implement SpacingConstants first, migrate incrementally, evaluate each change visually | Success Criteria: "personal daily-driver use" -- the creator must approve the visual result |
| R-2 | Zeroing the safe area (Approach A) or using `.ignoresSafeArea()` patterns (Approach B) may affect scroll indicator positioning, keyboard avoidance, or other system behaviors that rely on safe area insets | Some system behaviors may need manual compensation. Mitigation: test thoroughly with scrollbars visible and keyboard interactions. The validation spike in Phase 2a should check for these side effects. | Architecture: taking full ownership of the coordinate system means accepting responsibility for edge cases |

