import AppKit
import SwiftUI

/// Wrapper view that creates a per-window ``DocumentState`` and wires it into
/// the environment. Each ``WindowGroup`` instance embeds one `DocumentWindow`,
/// giving every window its own independent document lifecycle.
///
/// On appearance the view loads the file at `fileURL` (if non-nil), records it
/// in Open Recent, and publishes the ``DocumentState`` via `focusedSceneValue`
/// so menu commands can operate on the active window's document.
///
/// The view also observes ``FileOpenCoordinator/pendingURLs`` and opens a new
/// window for every URL that arrives at runtime (Finder, dock, other apps).
/// On the initial launch window (where `fileURL` is nil), pending URLs from
/// the CLI or a cold-start Finder open are adopted directly to avoid an extra
/// empty window.
public struct DocumentWindow: View {
    public let fileURL: URL?
    @State private var documentState = DocumentState()
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.openWindow) private var openWindow

    public init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    public var body: some View {
        ContentView()
            .environment(documentState)
            .environment(appSettings)
            .focusedSceneValue(\.documentState, documentState)
            .task {
                if let fileURL {
                    try? documentState.loadFile(at: fileURL)
                    NSDocumentController.shared.noteNewRecentDocumentURL(fileURL)
                } else if let launchURL = LaunchContext.consumeURL() {
                    try? documentState.loadFile(at: launchURL)
                    NSDocumentController.shared.noteNewRecentDocumentURL(launchURL)
                } else {
                    let pending = FileOpenCoordinator.shared.consumeAll()
                    if let first = pending.first {
                        try? documentState.loadFile(at: first)
                        NSDocumentController.shared.noteNewRecentDocumentURL(first)
                    }
                    for url in pending.dropFirst() {
                        openWindow(value: url)
                    }
                }
            }
            .onChange(of: FileOpenCoordinator.shared.pendingURLs) {
                for url in FileOpenCoordinator.shared.consumeAll() {
                    openWindow(value: url)
                }
            }
    }
}
