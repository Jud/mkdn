<!--
  Fixture: long-document.md
  Purpose: Contains 25+ top-level blocks for stagger animation testing.
  Used by: Animation compliance tests (stagger delay, stagger cap).

  Expected rendering characteristics:
  - 25+ distinct top-level blocks that trigger individual entrance animations
  - Each block enters with fadeIn + stagger delay (30ms per block)
  - Stagger cap of 500ms applies after ~16 blocks
  - Blocks beyond the cap share the tail of the stagger window
  - Mix of element types to ensure stagger works across all block variants
  - Total entrance sequence should complete within the stagger cap duration

  Block count: 28 top-level blocks (headings, paragraphs, code, lists,
  blockquotes, tables, thematic breaks).
-->

# Document Title

This is the introductory paragraph. It provides context for the document that follows and serves as the first visible content block after the heading.

## Section One

Paragraph one of section one. This text exists primarily to create a distinct block for stagger animation measurement.

Paragraph two of section one. Each paragraph is a separate block element that receives its own stagger delay offset.

Paragraph three of section one. By this point, the cumulative stagger delay should be noticeable in frame captures.

```swift
let block = "code block one"
print(block)
```

- List item alpha
- List item beta
- List item gamma

## Section Two

Paragraph one of section two. The stagger animation continues across section boundaries without resetting.

Paragraph two of section two. This is approximately the tenth block in the document.

> A blockquote in section two. Blockquotes are single blocks regardless of their internal line count.

Paragraph three of section two. We are now past the initial stagger delay accumulation phase.

1. Ordered item one
2. Ordered item two
3. Ordered item three

## Section Three

Paragraph one of section three. At this point we are approaching the stagger cap boundary around block sixteen.

Paragraph two of section three. Blocks near the stagger cap should show compressed timing.

Paragraph three of section three. This block is near or at the stagger cap threshold.

| Column A | Column B |
|----------|----------|
| Row 1A   | Row 1B   |
| Row 2A   | Row 2B   |

---

## Section Four

Paragraph one of section four. Blocks beyond the stagger cap share the tail of the stagger window.

Paragraph two of section four. The entrance animation duration remains constant; only the delay offset is capped.

Paragraph three of section four. Frame analysis should show these late blocks arriving in rapid succession.

```swift
let block = "code block two"
print(block)
```

## Section Five

Paragraph one of section five. This is block twenty-three or later in the sequence.

Paragraph two of section five. The document is intentionally verbose to exceed the stagger cap.

Paragraph three of section five. Final blocks should arrive nearly simultaneously due to cap compression.

- Final list item one
- Final list item two

This is the concluding paragraph. It marks the end of the long document and the last block in the stagger sequence.
