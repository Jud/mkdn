# Visual Testing with mkdn-ctl

Drive the running app via its test harness socket to visually verify rendering changes.

## Prerequisites

Launch mkdn with the test harness enabled:

```bash
swift run mkdn --test-harness          # build + run
# or, if already built:
.build/debug/mkdn --test-harness
```

The app opens normally and also listens on `/tmp/mkdn-test-harness-{pid}.sock`.

## Commands

```bash
scripts/mkdn-ctl ping                          # verify connection
scripts/mkdn-ctl load /path/to/file.md         # load a markdown file
scripts/mkdn-ctl capture /tmp/shot.png         # screenshot the window
scripts/mkdn-ctl scroll 500                    # scroll to y=500pt
scripts/mkdn-ctl theme solarizedDark           # set theme
scripts/mkdn-ctl theme solarizedLight
scripts/mkdn-ctl cycle                         # cycle through themes
scripts/mkdn-ctl info                          # window size, theme, loaded file
scripts/mkdn-ctl resize 1024 768               # resize window to 1024x768pt
scripts/mkdn-ctl recreate-view                 # rebuild the preview cold (see below)
scripts/mkdn-ctl quit                          # close the app
```

You can also set `MKDN_SOCK=/tmp/mkdn-test-harness-{pid}.sock` to target a specific instance.

## Driving the UI via Accessibility

In harness mode the app marks itself as hosting an assistive client
(`AXEnhancedUserInterface`), so the full accessibility tree — including
SwiftUI controls — is populated and drivable without mouse coordinates:

```bash
scripts/mkdn-ctl ax-tree [depth]               # dump roles/labels/identifiers/frames
scripts/mkdn-ctl press-button <title> [index]  # press by label, title, or identifier
scripts/mkdn-ctl ax-press <query> [action]     # press any element / run a named action
scripts/mkdn-ctl ax-rotors                     # list VoiceOver rotor items (headings/links/comments)
```

`ax-press` works on any element, not just buttons, and can trigger named
custom actions — e.g. `ax-press comment-card "Jump to Comment"`. `ax-rotors`
walks the same `NSAccessibilityCustomRotor` delegate VoiceOver's VO+U rotor
uses, so it verifies rotor navigation without running VoiceOver. Tables
render as labeled AX groups (`markdown-table` → "Header row"/"Row n" →
"Header: cell" texts).

`ax-tree` frames are window content coordinates (top-left origin), directly
usable with `click X Y`. Discover what's pressable with `ax-tree`, then press
it by its `identifier` (stable, preferred) or `label` (user-facing, can
change). Known identifiers: `comment-sidebar-toggle`, `comment-reply-button`,
`comment-card`, `comment-editor`, `comment-confirm-button`,
`comment-cancel-button`, `comment-edit-button`, `comment-delete-button`,
`copy-code-button`, `scroll-marker-track` (heading ticks are buttons labeled
`Heading: <title>` — pressing one scrolls to it), `outline-breadcrumb`,
`outline-heading-row`.

## Agent Workflow

When verifying visual changes during development:

1. **Create or update a fixture** in `fixtures/` that exercises the feature under test. Use dense, realistic content that stresses edge cases (wrapping text, wide tables, mixed elements).

2. **Launch the app** with `--test-harness` and load the fixture:
   ```bash
   scripts/mkdn-ctl load fixtures/table-test.md
   ```

3. **Capture screenshots** at relevant states. Add a `sleep 1` after `scroll` to let overlays (e.g. sticky table headers) reposition before capturing:
   ```bash
   scripts/mkdn-ctl theme solarizedDark
   scripts/mkdn-ctl capture /tmp/dark-top.png
   scripts/mkdn-ctl scroll 800 && sleep 1
   scripts/mkdn-ctl capture /tmp/dark-scrolled.png
   scripts/mkdn-ctl theme solarizedLight
   scripts/mkdn-ctl scroll 0 && sleep 1
   scripts/mkdn-ctl capture /tmp/light-top.png
   ```

4. **View the screenshots** using the `Read` tool (it handles images natively) to evaluate rendering quality.

5. **Iterate** -- fix issues, reload (`scripts/mkdn-ctl load ...`), re-capture, re-evaluate.

6. **Quit the app** when done:
   ```bash
   scripts/mkdn-ctl quit
   ```

## Cold First-Paint Testing

Some rendering bugs only appear on a document's **cold first paint** — the very
first `makeNSView` pass, before TextKit 2 has laid out anything below the
initial viewport. (Example: code-block backgrounds were once cached from
TextKit 2's *estimated* fragment frames for blocks below the fold, so they
rendered in the wrong place until a scroll forced real layout.)

The normal `load` command does **not** reproduce these: it swaps content into an
already-laid-out view (the warm `updateNSView` path, with real fragment frames).
A plain `capture` also waits on a render-complete signal that fires only after
the entrance animator has warmed layout.

Two ways to hit the cold path:

1. **Cold launch** — pass the file as a launch argument so the window's first
   paint *is* the target document, then capture immediately:
   ```bash
   .build/debug/mkdn --test-harness path/to/file.md
   scripts/mkdn-ctl capture /tmp/cold.png       # no load, no scroll, no hover
   ```

2. **`recreate-view`** — rebuild the preview cold in an already-running session
   (no relaunch). It changes the preview's SwiftUI identity, forcing a fresh
   `makeNSView`:
   ```bash
   scripts/mkdn-ctl load path/to/file.md
   scripts/mkdn-ctl recreate-view
   scripts/mkdn-ctl capture /tmp/cold.png       # no scroll, no hover
   ```

Use a file whose triggering element sits **below the initial viewport** — that's
the region TextKit 2 leaves estimated on first paint. `recreate-view` only has
an effect when a markdown preview is visible (not the welcome/source/plain-text
views). After capturing, a scroll or window resize forces real layout and the
bug "snaps" away — so capture before any such interaction.

## Fixtures

Test fixtures live in `fixtures/`. Each should target a specific rendering concern:

| Fixture | Purpose |
|---------|---------|
| `test-content.md` | Quick smoke test (one of each element type + mermaid) |
| `elements-test.md` | Comprehensive element rendering (headings, inline formatting, blockquotes, lists, code blocks, thematic breaks, mixed flow) |
| `table-test.md` | Table column sizing, wrapping, alignment, sticky headers, visual contrast |
| `codeblocks-test.md` | Code blocks across all supported languages (Swift highlighted, others monospace) |
| `mermaid-test.md` | All mermaid diagram types (flowchart, sequence, state, class, ER, Gantt, pie) |

When adding fixtures, include content that pushes boundaries: long text in cells, many columns, mixed narrow and wide content, deeply nested structures.

## Scroll Positions

The `scroll` command accepts a y-offset in points. Useful values:
- `0` -- top of document
- `info` command returns window height -- use this to calculate page-sized jumps
- Scroll is clamped to document bounds (won't scroll past content)

## Notes

- The harness waits for SwiftUI rendering to complete before returning from `load`, `theme`, and `cycle` commands, so captures taken immediately after are deterministic.
- `scroll` returns before overlay repositioning (sticky headers, etc.) completes. Add `sleep 1` between `scroll` and `capture` to ensure overlays are in their final positions.
- `capture` uses `CGWindowListCreateImage` targeting the window by ID, so the app does not need to be frontmost.
- In test harness mode the app launches as an accessory process (no dock icon, no focus steal).
