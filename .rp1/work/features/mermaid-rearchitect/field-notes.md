# Field Notes: Mermaid Re-Architect

## T1 Observations

### JXKit Was Never in Package.swift

The KB docs (modules.md, architecture.md) and design.md reference JXKit as a dependency, but the actual codebase used `import JavaScriptCore` (system framework) directly in `MermaidRenderer.swift`. JXKit was never added to Package.swift. The design doc was updated in Section 4 to note this: "JXKit was referenced in KB documentation but the actual codebase uses `import JavaScriptCore` (system framework) directly."

### MermaidError Was Defined Inside MermaidRenderer.swift

The `MermaidError` enum was defined at the bottom of `MermaidRenderer.swift`, not in its own file. When MermaidRenderer.swift was deleted, MermaidError went with it. T3 will recreate a simplified version.

### MermaidImageStore References in DocumentState and MarkdownPreviewView

T7 is scoped as "Remove MermaidImageStore reference from MarkdownPreviewView" but T1 required removing those references for compilation (T1 AC: "No dead imports or references to removed code remain" + "Project compiles after removal"). DocumentState.swift also had a `MermaidImageStore.shared.removeAll()` call that was cleaned up. T7 may be effectively complete after T1.

### Empty Gesture Directory Removed

After deleting `GestureIntentClassifier.swift` and `DiagramPanState.swift`, the `mkdn/Core/Gesture/` directory was empty. Removed the directory to keep the source tree clean.

### Pre-existing Debug Logging Changes

Several files (`DocumentWindow.swift`, `MarkdownBlockView.swift`) had pre-existing uncommitted debug logging changes. These were not touched by T1 and were excluded from the commit.
