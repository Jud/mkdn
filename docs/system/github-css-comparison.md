# GitHub Markdown CSS vs mkdn Rendering Constants

Reference comparison between [github-markdown-css](https://github.com/sindresorhus/github-markdown-css) and mkdn's `MarkdownTextStorageBuilder` constants.

## High-Impact Missing Features

### 1. Blockquote left border bar + muted text
GitHub blockquotes have a 4px left border in muted color + gray text. mkdn only indents.

### 2. h1/h2 bottom border separator
GitHub h1 and h2 have a 1px bottom border creating a clear section break. mkdn has none.

### 3. Inline code background pill
GitHub wraps inline `code` in a gray background with 6px radius and padding. mkdn has no background or padding on inline code.

## Element Comparison

### Base Typography

| Property | GitHub CSS | mkdn | Status |
|---|---|---|---|
| Base font size | 16px | ~13pt (`.body`) | DIVERGES |
| Line-height | 1.5x (24px) | lineSpacing: 2pt (additive) | DIVERGES |

### Headings

| Element | Property | GitHub | mkdn | Status |
|---|---|---|---|---|
| h1 | font-size | 32px (2em) | 28pt | DIVERGES |
| h1 | weight | semibold (600) | bold | DIVERGES |
| h1 | margin-top | 24px | 48pt | DIVERGES (mkdn 2x) |
| h1 | border-bottom | 1px solid | None | MISSING |
| h2 | font-size | 24px (1.5em) | 24pt | MATCH |
| h2 | border-bottom | 1px solid | None | MISSING |
| h3 | font-size | 20px (1.25em) | 20pt | MATCH |
| h4 | font-size | 16px (1em) | 18pt | DIVERGES |
| h5 | font-size | 14px (0.875em) | 16pt | DIVERGES |
| h6 | font-size | 13.6px (0.85em) | 14pt | MATCH |
| h6 | color | muted (gray) | same as other headings | DIVERGES |
| All | weight | semibold uniformly | bold h1-h2, semibold h3-h4, medium h5-h6 | DIVERGES |
| All | margin-top | 24px | varies (48/20/14pt) | DIVERGES |
| All | margin-bottom | 16px | 12pt | DIVERGES |

### Paragraph

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| margin-bottom | 10px | 12pt | DIVERGES (close) |

### Blockquote

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Left border | 4px solid muted | None (indent only) | MISSING |
| Padding-left | 16px (1em) | 19pt | DIVERGES |
| Text color | muted (gray) | normal foreground | MISSING |

### Inline Code

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Background | neutral-muted (gray pill) | None | MISSING |
| Padding | 3.2px 6.4px | None | MISSING |
| Border-radius | 6px | N/A | MISSING |
| Font size | 85% of base | systemFontSize | MATCH |

### Code Block

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Font size | 12px | 13pt | DIVERGES |
| Padding | 16px | 12pt | DIVERGES |
| Border-radius | 6px | 6pt | MATCH |
| Border | None (bg only) | 1px stroke 0.3 opacity | DIVERGES |
| Line-height | 1.45 | default | DIVERGES |

### Lists

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Indent | 32px (2em) | 36pt | DIVERGES |
| Item spacing | 4px | 4pt | MATCH |
| Bullet depth 0/1/2 | disc/circle/square | bullet/white-bullet/small-square | MATCH |
| Nested ol numbering | lower-roman, lower-alpha | always decimal | MISSING |

### Table

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Cell padding | 6px 13px | 6pt/13pt | MATCH |
| Header weight | semibold (600) | bold | DIVERGES |
| Corner radius | None (square) | 6pt rounded | DIVERGES (mkdn better) |
| Inter-row borders | 1px solid per row | None | MISSING |

### Horizontal Rule

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Height | 4px filled bar | 1pt thin line | DIVERGES |
| Margin | 24px top/bottom | 12pt | DIVERGES |

### Image

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Corner radius | None | 4pt | DIVERGES (mkdn better) |
| Alt text display | Hidden (HTML attr) | Caption below | DIVERGES (mkdn better) |

### Links

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Underline | On hover only | Always | DIVERGES (mkdn appropriate for native) |

### Strong

| Property | GitHub | mkdn | Status |
|---|---|---|---|
| Weight | semibold (600) | bold (700) | DIVERGES (subtle) |

## Intentional Divergences (Keep mkdn's Approach)

- **Table rounded corners** — looks better in native context
- **Image rounded corners + alt text captions** — improvement over GitHub
- **Always-underlined links** — better for non-hover native context
- **Loading/error image placeholders** — native app advantage
- **Code block language label** — useful mkdn-specific feature

## Implementation Priority

1. Blockquote left border bar + muted text color
2. h1/h2 bottom border separator
3. Inline code background/padding pill
4. Heading margin normalization (especially h1 spacing-before)
5. Code block font/padding alignment
6. Table inter-row borders
7. Nested ordered list numbering styles (lower-roman, lower-alpha)
8. h6 muted color
