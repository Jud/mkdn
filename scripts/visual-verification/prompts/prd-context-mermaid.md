# PRD Context: Mermaid Diagram Rendering

Source: mermaid-rendering PRD v1.0.0

## Rendering Pipeline

Mermaid diagrams are rendered entirely in-process via a native pipeline:
Mermaid text -> JavaScriptCore (JXKit) + beautiful-mermaid.js -> SVG string -> SwiftDraw rasterization -> NSImage -> SwiftUI Image

No WKWebView is used for diagram rendering (project-wide architectural constraint).

## FR-4: Async Rendering with UI States

Mermaid blocks display three possible states:
1. **Loading**: a spinner/progress indicator while the diagram renders
2. **Success**: the rendered diagram image displayed inline in the document
3. **Error**: a warning icon and error message if rendering fails

## FR-5: Gesture Support

Rendered diagrams support:
- `MagnifyGesture` pinch-to-zoom (0.5x to 4.0x range)
- Two-finger scroll/pan within the diagram via horizontal + vertical ScrollView

## FR-6: Scroll Isolation

Mermaid diagrams must NEVER capture or hijack the parent document scroll. When scrolling the document vertically, scroll events must pass through diagram views without getting trapped. Diagram-internal scrolling requires explicit activation (click-to-focus).

## FR-7: Theme Integration

Diagram containers use theme-appropriate colors:
- Container background: `backgroundSecondary` from the active theme
- Text/label colors: `foregroundSecondary` from the active theme

## FR-9: Supported Diagram Types

Five diagram types are supported:
1. **Flowchart**: directed graphs with nodes and edges
2. **Sequence**: interaction diagrams with participants and messages
3. **State**: state machine diagrams with states and transitions
4. **Class**: UML class diagrams with classes and relationships
5. **ER** (Entity-Relationship): database relationship diagrams

## Visual Evaluation Notes for Mermaid Rendering

When evaluating screenshots against this PRD:
- Verify diagrams are rendered as images (not raw Mermaid text)
- Check that diagram containers have a distinct background from the document
- Verify all supported diagram types render correctly (flowchart, sequence, class, state)
- Check that diagram elements (nodes, edges, labels, arrows) are clearly visible and readable
- Verify diagrams are properly sized within the document flow (not clipped, not oversized)
- Check that diagram containers integrate harmoniously with surrounding document content
- Verify the diagram background color matches the theme's secondary background
- Look for any rendering artifacts (broken arrows, overlapping labels, clipped text)
- Check that multiple diagrams in the same document are rendered consistently
