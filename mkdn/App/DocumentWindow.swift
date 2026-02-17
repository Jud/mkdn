import AppKit
import SwiftUI

/// Wrapper view that creates a per-window ``DocumentState`` and wires it into
/// the environment. Each ``WindowGroup`` instance embeds one `DocumentWindow`,
/// giving every window its own independent document lifecycle.
///
/// On appearance the view loads the file at the launch item URL (if a file),
/// records it in Open Recent, and publishes the ``DocumentState`` via
/// `focusedSceneValue` so menu commands can operate on the active window's
/// document.
///
/// The view also observes ``FileOpenCoordinator/pendingURLs`` and opens a new
/// window for every URL that arrives at runtime (Finder, dock, other apps).
/// On the initial launch window (where `launchItem` is nil), pending URLs from
/// the CLI or a cold-start Finder open are adopted directly to avoid an extra
/// empty window.
public struct DocumentWindow: View {
    public let launchItem: LaunchItem?
    @State private var documentState = DocumentState()
    @State private var findState = FindState()
    @State private var directoryState: DirectoryState?
    @State private var isReady = false
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.openWindow) private var openWindow

    public init(launchItem: LaunchItem?) {
        self.launchItem = launchItem
    }

    public var body: some View {
        Group {
            if let directoryState {
                DirectoryContentView()
                    .environment(directoryState)
                    .focusedSceneValue(\.directoryState, directoryState)
            } else {
                ContentView()
                    .background(appSettings.theme.colors.background.ignoresSafeArea())
            }
        }
        .environment(documentState)
        .environment(findState)
        .environment(appSettings)
        .focusedSceneValue(\.documentState, documentState)
        .focusedSceneValue(\.findState, findState)
        .opacity(isReady ? 1 : 0)
        .onAppear {
            handleLaunch()
            if TestHarnessMode.isEnabled {
                TestHarnessHandler.appSettings = appSettings
                TestHarnessHandler.documentState = documentState
                TestHarnessHandler.directoryState = directoryState
                TestHarnessServer.shared.start()
            }
            isReady = true
        }
        .onChange(of: FileOpenCoordinator.shared.pendingURLs) {
            for url in FileOpenCoordinator.shared.consumeAll() {
                openWindow(value: LaunchItem.file(url))
            }
        }
    }

    private func handleLaunch() {
        switch launchItem {
        case let .file(url):
            try? documentState.loadFile(at: url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)

        case let .directory(url):
            setupDirectoryState(rootURL: url)

        case nil:
            consumeLaunchContext()
        }
    }

    private func setupDirectoryState(rootURL: URL) {
        let dirState = DirectoryState(rootURL: rootURL)
        dirState.documentState = documentState
        directoryState = dirState
        dirState.scan()
    }

    private func consumeLaunchContext() {
        let launchFileURLs = LaunchContext.consumeURLs()
        let launchDirURLs = LaunchContext.consumeDirectoryURLs()

        if !launchFileURLs.isEmpty || !launchDirURLs.isEmpty {
            if let first = launchFileURLs.first {
                try? documentState.loadFile(at: first)
                NSDocumentController.shared.noteNewRecentDocumentURL(first)
            } else if let firstDir = launchDirURLs.first {
                setupDirectoryState(rootURL: firstDir)
            }
            for url in launchFileURLs.dropFirst() {
                openWindow(value: LaunchItem.file(url))
            }
            let remainingDirs = launchFileURLs.isEmpty
                ? Array(launchDirURLs.dropFirst())
                : launchDirURLs
            for url in remainingDirs {
                openWindow(value: LaunchItem.directory(url))
            }
        } else {
            let pending = FileOpenCoordinator.shared.consumeAll()
            if let first = pending.first {
                try? documentState.loadFile(at: first)
                NSDocumentController.shared.noteNewRecentDocumentURL(first)
            }
            for url in pending.dropFirst() {
                openWindow(value: LaunchItem.file(url))
            }
        }
    }
}
