import AppKit
import SwiftUI

/// Conditionally injects ``DirectoryState`` into the environment when present.
private struct OptionalDirectoryEnvironment: ViewModifier {
    let directoryState: DirectoryState?

    func body(content: Content) -> some View {
        if let directoryState {
            content
                .environment(directoryState)
                .focusedSceneValue(\.directoryState, directoryState)
        } else {
            content
        }
    }
}

/// Wrapper view that creates a per-window ``DocumentState`` and wires it into
/// the environment. Each ``WindowGroup`` instance embeds one `DocumentWindow`,
/// giving every window its own independent document lifecycle.
///
/// On appearance the view loads the file at the launch item URL (if a file),
/// records it in Open Recent, and publishes the ``DocumentState`` via
/// `focusedSceneValue` so menu commands can operate on the active window's
/// document.
///
/// The view also observes ``FileOpenService/pendingURLs`` and opens a new
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    private var sidebarOffset: CGFloat {
        documentState.isSidebarVisible
            ? documentState.sidebarWidth + SidebarDivider.width
            : 0
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    sidebarContent
                        .frame(width: documentState.sidebarWidth)

                    SidebarDivider()
                }

                ContentView()
                    .frame(width: geometry.size.width - sidebarOffset)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: documentState.isSidebarVisible ? 10 : 0,
                            bottomLeadingRadius: documentState.isSidebarVisible ? 10 : 0
                        )
                    )
                    .offset(x: sidebarOffset)
            }
        }
        .background(appSettings.theme.colors.backgroundSecondary)
        .environment(\.isDirectoryMode, directoryState != nil)
        .animation(motion.resolved(.sidebarSlide), value: documentState.isSidebarVisible)
        .animation(motion.resolved(.sidebarSlide), value: documentState.sidebarWidth)
        .ignoresSafeArea()
        .frame(minWidth: 600, minHeight: 400)
        .environment(documentState)
        .environment(findState)
        .environment(appSettings)
        .focusedSceneValue(\.documentState, documentState)
        .focusedSceneValue(\.findState, findState)
        .modifier(OptionalDirectoryEnvironment(directoryState: directoryState))
        .opacity(isReady ? 1 : 0)
        .onAppear {
            handleLaunch()
            if TestHarnessMode.isEnabled {
                TestHarnessHandler.appSettings = appSettings
                TestHarnessHandler.documentState = documentState
                TestHarnessServer.shared.start()
            }
            FileOpenService.shared.openFileWindow = { [openWindow] url in
                openWindow(value: LaunchItem.file(url))
            }
            isReady = true
        }
        .onChange(of: FileOpenService.shared.pendingURLs) {
            for url in FileOpenService.shared.consumePendingURLs() {
                openWindow(value: LaunchItem.file(url))
            }
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if let directoryState {
            SidebarView()
                .environment(directoryState)
        } else {
            SidebarPlaceholderView { url in
                setupDirectoryState(rootURL: url)
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
        documentState.isSidebarVisible = true
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
            let pending = FileOpenService.shared.consumePendingURLs()
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
