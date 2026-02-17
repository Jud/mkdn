# Mermaid Diagram Rendering Test

## Flowchart (LR)

```mermaid
graph LR
    A[Start] --> B{Is valid?}
    B -->|Yes| C[Process]
    B -->|No| D[Reject]
    C --> E[Save]
    D --> F[Log Error]
    E --> G[End]
    F --> G
```

## Flowchart (TD)

```mermaid
graph TD
    CLI[CLI Entry Point] --> Parse[Parse Arguments]
    Parse --> Validate{Valid?}
    Validate -->|File| LoadFile[Load Markdown File]
    Validate -->|Directory| LoadDir[Open Directory Sidebar]
    Validate -->|Invalid| Error[Show Error & Exit]
    LoadFile --> Render[Render Document]
    LoadDir --> Scan[Scan Directory Tree]
    Scan --> Render
    Render --> Display[Display in Window]
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant App
    participant Parser
    participant Renderer
    participant WKWebView

    User->>App: Open file.md
    App->>Parser: Parse markdown
    Parser-->>App: MarkdownBlock tree
    App->>Renderer: Build NSAttributedString
    Renderer-->>App: Attributed text + attachments

    loop For each mermaid block
        App->>WKWebView: Render diagram
        WKWebView-->>App: Rendered height
    end

    App->>User: Display document
    User->>App: Scroll / Resize
    App->>Renderer: Reposition overlays
```

## State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading: Open File
    Loading --> Rendered: Parse + Render
    Loading --> Error: Parse Failed
    Error --> Idle: Dismiss
    Rendered --> Idle: Close File
    Rendered --> Loading: Reload
    Rendered --> Searching: Cmd+F
    Searching --> Rendered: Escape
    Searching --> Searching: Type Query
```

## Class Diagram

```mermaid
classDiagram
    class AppSettings {
        +AppTheme theme
        +CGFloat scaleFactor
        +Bool autoReloadEnabled
        +zoomIn()
        +zoomOut()
        +cycleTheme()
    }

    class DocumentState {
        +URL? fileURL
        +String? directoryPath
        +Bool isFullReload
    }

    class FindState {
        +String query
        +Int currentMatchIndex
        +[NSRange] matchRanges
        +performSearch(in: String)
        +nextMatch()
        +previousMatch()
    }

    class OverlayCoordinator {
        -[Int: OverlayEntry] entries
        -[Int: NSView] stickyHeaders
        +updateOverlays()
        +repositionOverlays()
        +removeAllOverlays()
    }

    AppSettings --> DocumentState
    DocumentState --> FindState
    OverlayCoordinator --> AppSettings
```

## Entity Relationship

```mermaid
erDiagram
    DOCUMENT ||--o{ BLOCK : contains
    BLOCK ||--o{ INLINE : contains
    DOCUMENT {
        string filePath
        date lastModified
        string theme
    }
    BLOCK {
        string type
        int index
        string content
    }
    INLINE {
        string type
        string text
        string href
    }
    BLOCK ||--o| ATTACHMENT : "may have"
    ATTACHMENT {
        string blockType
        float width
        float height
    }
```

## Gantt Chart

```mermaid
gantt
    title mkdn Development Timeline
    dateFormat YYYY-MM-DD
    section Core
        Markdown Parser       :done, 2026-01-01, 2026-01-15
        TextKit 2 Renderer    :done, 2026-01-10, 2026-01-25
        Theme System          :done, 2026-01-20, 2026-02-01
    section Features
        Find Bar              :done, 2026-01-25, 2026-02-05
        Mermaid Diagrams      :done, 2026-02-01, 2026-02-10
        Directory Sidebar     :active, 2026-02-10, 2026-02-20
    section Polish
        Table Rendering       :active, 2026-02-15, 2026-02-18
        Visual Testing        :2026-02-18, 2026-02-22
```

## Pie Chart

```mermaid
pie title Code Distribution by Module
    "Core/Markdown" : 35
    "Features/Viewer" : 25
    "UI/Theme" : 15
    "App" : 10
    "Features/Sidebar" : 10
    "Core/TestHarness" : 5
```

## Text Between Diagrams

This paragraph sits between two Mermaid diagrams to verify spacing and that each diagram gets its own WKWebView instance without interference.

## Simple Decision Flow

```mermaid
graph LR
    A[Markdown?] -->|Yes| B[Render Native]
    A -->|No| C{Mermaid?}
    C -->|Yes| D[WKWebView]
    C -->|No| E[Plain Text]
```

End of mermaid test. Text after the last diagram should render normally.
