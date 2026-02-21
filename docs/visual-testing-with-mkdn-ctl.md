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
scripts/mkdn-ctl quit                          # close the app
```

You can also set `MKDN_SOCK=/tmp/mkdn-test-harness-{pid}.sock` to target a specific instance.

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
