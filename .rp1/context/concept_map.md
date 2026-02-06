# mkdn Concept Map

## Domain Concepts

```
Markdown File (.md)
  |
  +---> Document (parsed AST)
  |       |
  |       +---> Block Elements
  |       |       +---> Heading (H1-H6)
  |       |       +---> Paragraph
  |       |       +---> Code Block (fenced, with language)
  |       |       +---> Mermaid Block (code block with mermaid lang)
  |       |       +---> Blockquote
  |       |       +---> List (ordered, unordered)
  |       |       +---> Table
  |       |       +---> Thematic Break
  |       |
  |       +---> Inline Elements
  |               +---> Text
  |               +---> Emphasis / Strong
  |               +---> Code (inline)
  |               +---> Link
  |
  +---> File State
          +---> Current (matches disk)
          +---> Outdated (disk changed)
          +---> Unsaved (editor changed)

View Modes
  +---> Preview Only (read)
  +---> Side-by-Side (edit + preview)

Themes
  +---> Solarized Dark
  +---> Solarized Light

Mermaid Diagram Types
  +---> Flowchart
  +---> Sequence
  +---> State
  +---> Class
  +---> ER (Entity-Relationship)
```

## User Workflows

1. **Quick View**: `mkdn file.md` -> preview opens -> read -> close
2. **Edit**: Open -> toggle to side-by-side -> edit -> Cmd+S -> close
3. **Monitor**: Open -> file changes externally -> see indicator -> click reload
4. **Diagram Review**: Open file with Mermaid -> pinch-to-zoom on diagram
