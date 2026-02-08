<!--
  Fixture: mermaid-focus.md
  Purpose: Contains multiple Mermaid diagrams for focus interaction testing.
  Used by: Mermaid focus activation/deactivation tests, WKWebView capture
           timing tests, visual compliance tests for diagram rendering.

  Expected rendering characteristics:
  - Four Mermaid diagrams of different types (flowchart, sequence, class, state)
  - Each diagram renders in its own WKWebView instance
  - Click-to-focus interaction model: clicking a diagram activates focus border
  - Focus border uses springSettle animation with focusBorderWidth (2pt)
  - Focus glow uses focusGlowRadius (6pt) with orbGlowColor
  - Unfocused diagrams show hoverBrightness (0.03 white overlay) on hover
  - Render completion must wait for all WKWebView instances to finish
  - Paragraphs between diagrams provide spacing context for spatial tests
-->

# Mermaid Diagram Gallery

This document contains multiple Mermaid diagrams for testing focus interaction, render timing, and visual compliance.

## Flowchart

A standard flowchart with decision nodes and multiple paths.

```mermaid
graph TD
    A[Initialize App] --> B{Config Valid?}
    B -->|Yes| C[Load Theme]
    B -->|No| D[Show Error]
    C --> E[Parse Markdown]
    E --> F{Has Mermaid?}
    F -->|Yes| G[Render Diagrams]
    F -->|No| H[Display Content]
    G --> H
    D --> I[Exit]
```

## Sequence Diagram

A sequence diagram showing component interactions.

```mermaid
sequenceDiagram
    participant W as FileWatcher
    participant S as AppState
    participant R as MarkdownRenderer
    participant V as PreviewView
    participant M as MermaidRenderer

    W->>S: File changed notification
    S->>R: Re-parse content
    R->>R: Walk AST
    R-->>S: [MarkdownBlock] array
    S->>V: Update view
    V->>M: Render mermaid blocks
    M-->>V: SVG images
    V->>V: Composite layout
```

## Class Diagram

A class diagram showing the data model relationships.

```mermaid
classDiagram
    class AppTheme {
        +colors: ThemeColors
        +syntaxColors: SyntaxColors
    }
    class ThemeColors {
        +background: Color
        +foreground: Color
        +headingColor: Color
        +codeBackground: Color
    }
    class SyntaxColors {
        +keyword: Color
        +string: Color
        +comment: Color
        +type: Color
    }
    AppTheme --> ThemeColors
    AppTheme --> SyntaxColors
```

## State Diagram

A state diagram showing view mode transitions.

```mermaid
stateDiagram-v2
    [*] --> Welcome
    Welcome --> PreviewOnly: Open File
    PreviewOnly --> SideBySide: Toggle Mode
    SideBySide --> PreviewOnly: Toggle Mode
    PreviewOnly --> PreviewOnly: Reload
    SideBySide --> SideBySide: Reload
    PreviewOnly --> Welcome: Close File
    SideBySide --> Welcome: Close File
```

This paragraph follows the final diagram to verify spacing between a Mermaid block and subsequent content.
