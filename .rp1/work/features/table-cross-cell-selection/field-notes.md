# Field Notes: Table Cross-Cell Selection

## TX-snapshot-verify: Visual Verification Report (2026-02-23)

### Summary

Visual verification of FR-007 (Visual Rendering Parity) using the mkdn-ctl test harness against `fixtures/table-test.md` across Solarized Dark and Solarized Light themes.

**Verdict**: PARTIAL PASS -- Tables render correctly in structure and theme consistency, but a significant vertical gap artifact exists between table headings and table bodies for tables with wrapping cell content.

### Screenshots Captured

| Screenshot | Theme | Scroll | Content Visible |
|------------|-------|--------|-----------------|
| dark-top (y=0) | Solarized Dark | 0 | Simple 3-Column, Wide Content, Minimal 2-Column header |
| dark-mid (y=600) | Solarized Dark | 600 | Minimal 2-Column, Alignment Test, Wrapping Text heading |
| dark-bottom (y=1200) | Solarized Dark | 1200 | Wrapping Text sticky header + table body (with gap) |
| dark-end (y=2000) | Solarized Dark | 2000 | End of Wrapping Text table |
| light-top (y=0) | Solarized Light | 0 | Same as dark-top (light theme) |
| light-mid (y=600) | Solarized Light | 600 | Same as dark-mid (light theme) |
| light-bottom (y=1200) | Solarized Light | 1200 | Same as dark-bottom (light theme) |
| light-end (y=2000) | Solarized Light | 2000 | Same as dark-end (light theme) |
| Additional gap investigation: y=700, 900, 1100, 2400, 2700, 3000, 4000, 5000 |

### FR-007 AC-1: No Visual Differences (Screenshot Comparison)

**Status**: FAIL -- Vertical gap artifact

**Positive findings** (table rendering within the visual overlay is correct):
- All 7 table types from the fixture render: Simple 3-Column, Wide Content, Minimal 2-Column, Alignment Test, Wrapping Text, 5-Column Dense, Long Table (25 rows)
- Header rows are visually distinct (bold text, subtle background differentiation)
- Alternating row backgrounds visible in both themes
- Rounded borders present on all tables
- Column alignment (left, center, right) works correctly in the Alignment Test table
- Text wrapping within cells works correctly -- long content wraps to multiple lines within cells
- Cell padding is consistent
- Column widths are proportional to content

**Issue: Vertical gap between heading and table body**

A significant empty gap appears between each section heading and the visible table body for tables with wrapping cell content. The gap scales with table content length:

| Table | Approximate Gap (pt) | Content Wraps? |
|-------|---------------------|----------------|
| Simple 3-Column | ~0 (none) | No |
| Minimal 2-Column | ~0 (none) | No |
| Alignment Test | ~0 (none) | No |
| Wide Content | ~80-100 | Yes (file paths wrap) |
| 5-Column Dense | ~200-250 | Yes (descriptions wrap) |
| Wrapping Text | ~500-600 | Yes (heavy wrapping in all columns) |
| Long Table | ~250-300 | Yes (descriptions wrap) |

**Root cause hypothesis**: The invisible text layer generates one line of tab-separated text per table row. The paragraph style sets a fixed minimum line height, but for tables with wrapping content, the visual SwiftUI overlay rows are taller (because text wraps within cells). The invisible text does not wrap the same way, so the total invisible text height differs from the visual overlay height. The visual overlay is positioned over the layout fragments of the invisible text, but the size mismatch creates empty space visible as a gap between the preceding heading and the visible table.

Tables with short, non-wrapping content (Simple 3-Column, Minimal 2-Column, Alignment Test) do not exhibit this gap because the invisible text line height matches the visual row height for single-line content.

### FR-007 AC-2: All Themes Render Tables Identically

**Status**: PASS

Both Solarized Dark and Solarized Light render tables with identical structure:
- Same column widths and proportions
- Same text wrapping behavior
- Same cell padding and alignment
- Appropriate theme-specific colors (dark bg + light text vs. light bg + dark text)
- Both themes exhibit the same gap artifact (consistent behavior)
- Header styling is theme-appropriate in both variants

### FR-007 AC-3: Column Sizing, Cell Padding, Text Alignment Preserved

**Status**: PASS (within the visible table overlay)

- Left alignment: text left-aligned in the Alignment Test table
- Center alignment: text centered in the Center column
- Right alignment: text right-aligned in the Right column (numbers like "42", "1,234,567" align right)
- Column sizing proportional to content across all tables
- Cell padding consistent throughout

### FR-010 (Sticky Header) Observation

Sticky headers ARE working -- visible at y=1100 (Wrapping Text), y=2400 (Wrapping Text), y=4000 (Long Table), y=5000 (Long Table). The header pins at the viewport top when scrolling through tall tables.

Minor observation: At y=1100, the sticky header for the Wrapping Text table shows "Decision" wrapped awkwardly ("Decisi" / "on") due to the narrow first column. This appears to be a pre-existing column sizing behavior, not a regression.

### Recommendations

1. ~~**Critical**: Fix the vertical gap between headings and table bodies.~~ **RESOLVED** in TX-gap-fix (see below).

2. ~~**Minor**: The gap artifact is most severe for tables with heavy text wrapping.~~ **RESOLVED** in TX-gap-fix.

## TX-gap-fix: Vertical Gap Bug Fix (2026-02-24)

### Root Cause

The original hypothesis (row height estimation at 600pt vs actual width) was only part of the story. The primary cause was that the invisible text paragraph style used the default `lineBreakMode = .byWordWrapping`. Since each table row is a single paragraph of tab-separated cell text, long rows wrapped to multiple visual lines in the NSTextView. Each wrapped line received `minimumLineHeight = rowHeight`, so a row wrapping to N lines consumed N times the intended height.

For the "Wrapping Text" table with 4 data rows and heavy cell content, rows could wrap to 3-4 visual lines each, inflating the invisible text region by 3-4x the visual overlay height.

### Fix

Two changes:

1. **`lineBreakMode = .byClipping`** on the paragraph style in `appendTableInlineRow` (MarkdownTextStorageBuilder+TableInline.swift). This prevents the tab-separated text from wrapping to multiple lines. Each row paragraph is rendered as exactly one line at the specified `minimumLineHeight`/`maximumLineHeight`. Since the text is invisible (clear foreground), clipping has no visual effect, but selection/find/clipboard operations still work on the full text storage content.

2. **`layoutSubtreeIfNeeded()`** before `fittingSize` query in `scaleToVisualHeight` (OverlayCoordinator+TableHeights.swift). Ensures the NSHostingView has completed its first layout pass before querying intrinsic content size for proportional height scaling.

### Verification

Verified with `fixtures/table-test.md` across all 7 table types in both Solarized Dark and Solarized Light themes. All tables render with no vertical gap artifact. The document is now compact: tables appear immediately after their section headings with normal block spacing.

| Table | Gap Before Fix | Gap After Fix |
|-------|---------------|---------------|
| Simple 3-Column | ~0 | ~0 |
| Minimal 2-Column | ~0 | ~0 |
| Alignment Test | ~0 | ~0 |
| Wide Content | ~80-100pt | ~0 |
| 5-Column Dense | ~200-250pt | ~0 |
| Wrapping Text | ~500-600pt | ~0 |
| Long Table | ~250-300pt | ~0 |
