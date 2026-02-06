import SwiftUI
import UniformTypeIdentifiers

/// Root content view that switches between preview-only and side-by-side modes.
public struct ContentView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        Group {
            if appState.currentFileURL == nil {
                WelcomeView()
            } else {
                switch appState.viewMode {
                case .previewOnly:
                    MarkdownPreviewView()
                        .transition(.opacity)
                case .sideBySide:
                    SplitEditorView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.viewMode)
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            MkdnToolbarContent()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, url.pathExtension == "md" || url.pathExtension == "markdown" else {
                return
            }
            Task { @MainActor in
                try? appState.loadFile(at: url)
            }
        }
        return true
    }
}

// MARK: - Toolbar

private struct MkdnToolbarContent: ToolbarContent {
    @Environment(AppState.self) private var appState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if appState.hasUnsavedChanges {
                UnsavedIndicator()
            }

            if appState.isFileOutdated {
                OutdatedIndicator()
            }

            ViewModePicker()

            Button {
                openFile()
            } label: {
                Label("Open", systemImage: "doc")
            }
        }
    }

    @MainActor
    private func openFile() {
        let panel = NSOpenPanel()
        if let mdType = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [mdType]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? appState.loadFile(at: url)
    }
}
