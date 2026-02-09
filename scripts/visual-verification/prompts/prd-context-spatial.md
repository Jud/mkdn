# PRD Context: Spatial Design Language

Source: spatial-design-language PRD v1.1.0

## FR-1: 8pt Grid Primitives

Named spacing primitives on the 8pt grid:

| Primitive | Value | Role |
|-----------|-------|------|
| `micro` | 4pt | Sub-grid half-step for optical adjustments |
| `compact` | 8pt | Tight internal spacing (list items, inline elements) |
| `cozy` | 12pt | Component internal padding (code blocks, blockquotes) |
| `standard` | 16pt | Block-to-block spacing, nested indentation base |
| `relaxed` | 24pt | Section separation, generous internal padding |
| `spacious` | 32pt | Document margins, major section breaks |
| `generous` | 48pt | Hero spacing, above H1 |
| `expansive` | 64pt | Maximum spacing primitive |

All values are multiples of 4pt (grid-aligned).

## FR-2: Document Layout Constants

| Constant | Value | Design Grounding |
|----------|-------|------------------|
| `documentMargin` | 32pt (`spacious`) | Margins frame content with room to breathe |
| `contentMaxWidth` | ~680pt | 45-90 characters per line at body size; ~65-75 chars optimal |
| `blockSpacing` | 16pt (`standard`) | Consistent vertical rhythm between equal-weight elements |

## FR-3: Typography Spacing Constants

| Constant | Value | Design Grounding |
|----------|-------|------------------|
| `bodyLineHeight` | 1.4-1.5x font size | Balanced density and readability |
| `paragraphSpacing` | 50-100% of line-height | Perceptibly more than line spacing but not a full blank line |
| `headingSpaceAbove` (H1) | 48pt (`generous`) | Large space above signals new major section |
| `headingSpaceBelow` (H1) | 16pt (`standard`) | Heading belongs to what follows -- asymmetric margin creates visual binding |
| `headingSpaceAbove` (H2) | 32pt (`spacious`) | Proportional reduction from H1; still clearly a section break |
| `headingSpaceBelow` (H2) | 12pt (`cozy`) | Tighter binding to following content than H1 |
| `headingSpaceAbove` (H3) | 24pt (`relaxed`) | Sub-section signal; less dramatic than H2 |
| `headingSpaceBelow` (H3) | 8pt (`compact`) | Tight binding; H3 is closely coupled to its content |

Key invariant: headings have more space above than below (Gestalt proximity -- heading binds to what follows).

## FR-4: Component Spacing Constants

| Constant | Value | Design Grounding |
|----------|-------|------------------|
| `componentPadding` | 12pt (`cozy`) | Internal padding for code blocks, blockquotes |
| `listItemSpacing` | 8pt (`compact`) | List items are a tight group; less than paragraph spacing |
| `nestedIndent` | 16-24pt (`standard` to `relaxed`) | Enough to signal hierarchy without wasting horizontal space |
| `blockquoteBorderPadding` | 12pt (`cozy`) | Internal padding from blockquote border to content |
| `listGutterWidth` | 24pt (`relaxed`) | Width for bullet/number column |

## FR-5: Structural Rules

1. Internal <= External: component internal padding never exceeds spacing between components
2. All primitives named: no raw numeric literals for spacing in view code
3. Design rationale documented for every constant
4. Grid-aligned: all values are multiples of 4pt

## FR-6: Window Chrome Spacing

| Constant | Value | Design Grounding |
|----------|-------|------------------|
| `windowTopInset` | 32pt (`spacious`) | Generous top margin from chromeless window edge |
| `windowSideInset` | 32pt (`spacious`) | Symmetric side framing matching documentMargin |
| `windowBottomInset` | 24pt (`relaxed`) | Slightly less than top, drawing eye upward |

## Visual Evaluation Notes

When evaluating screenshots against this PRD:
- Measure document margins (left/right whitespace from window edge to content)
- Check heading spacing asymmetry (more space above than below)
- Verify heading hierarchy (H1 space > H2 space > H3 space)
- Check block-to-block spacing consistency for same-type elements
- Verify code block and blockquote internal padding
- Check list item spacing is tighter than paragraph spacing
- Verify content width does not exceed ~680pt (the reading measure)
