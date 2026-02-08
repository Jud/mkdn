<!--
  Fixture: geometry-calibration.md
  Purpose: Known-geometry elements for spatial measurement calibration.
  Used by: Spatial compliance calibration tests, measurement accuracy
           verification before running the full spatial compliance suite.

  Expected rendering characteristics:
  - Minimal content to reduce measurement ambiguity
  - Each section tests one specific spatial relationship
  - Known expected values (from spatial-design-language PRD or SpacingConstants):
      Document margin: 32pt (left and right from window edge to content)
      Block spacing: 16pt (between consecutive paragraph blocks)
      H1 space above: 48pt (above H1 heading)
      H1 space below: 24pt (below H1 heading before next block)
      H2 space above: 36pt (above H2 heading)
      H2 space below: 20pt (below H2 heading before next block)
      H3 space above: 28pt (above H3 heading)
      H3 space below: 16pt (below H3 heading before next block)
      Code block padding: 12pt (internal padding within code block)
      Blockquote padding: 12pt (internal padding within blockquote)
      Window top inset: 32pt (from window top to first content)
      Window side inset: 32pt (from window side to content edge)
      Window bottom inset: 24pt (from last content to window bottom)
      Content max width: ~680pt (maximum content column width)

  Calibration strategy:
  - Section 1: H1 followed by paragraph measures heading spacing
  - Section 2: Two consecutive paragraphs measure block spacing
  - Section 3: H2 followed by paragraph measures H2 heading spacing
  - Section 4: H3 followed by paragraph measures H3 heading spacing
  - Section 5: Code block for component padding measurement
  - Section 6: Blockquote for component padding measurement
  - Each section is separated by thematic breaks for visual clarity
  - Content is short single-line text to avoid line-wrapping ambiguity
-->

# Calibration Heading One

This paragraph follows H1 for spacing measurement.

---

This is the first measurement paragraph.

This is the second measurement paragraph.

---

## Calibration Heading Two

This paragraph follows H2 for spacing measurement.

---

### Calibration Heading Three

This paragraph follows H3 for spacing measurement.

---

```swift
let calibration = "code block padding measurement"
```

---

> Blockquote for padding measurement.
