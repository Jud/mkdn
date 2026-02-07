import AppKit

/// Handles system file-open events and routes them through ``FileOpenCoordinator``.
///
/// Wired into the SwiftUI lifecycle via `@NSApplicationDelegateAdaptor(AppDelegate.self)`.
/// Receives `application(_:open:)` calls from Launch Services when the user opens
/// Markdown files from Finder, dock drag-and-drop, or other applications.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationWillFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    public func application(_: NSApplication, open urls: [URL]) {
        let markdownURLs = urls.filter { FileOpenCoordinator.isMarkdownURL($0) }
        for url in markdownURLs {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            FileOpenCoordinator.shared.pendingURLs.append(url)
        }
    }

    public func applicationShouldHandleReopen(
        _: NSApplication,
        hasVisibleWindows _: Bool
    ) -> Bool {
        true
    }
}
