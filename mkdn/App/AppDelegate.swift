import AppKit

/// Handles system file-open events and routes them through ``FileOpenCoordinator``.
///
/// Wired into the SwiftUI lifecycle via `@NSApplicationDelegateAdaptor(AppDelegate.self)`.
/// Receives `application(_:open:)` calls from Launch Services when the user opens
/// Markdown files from Finder, dock drag-and-drop, or other applications.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObserver: (any NSObjectProtocol)?

    public func application(_: NSApplication, open urls: [URL]) {
        let markdownURLs = urls.filter { FileOpenCoordinator.isMarkdownURL($0) }
        for url in markdownURLs {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            FileOpenCoordinator.shared.pendingURLs.append(url)
        }
    }

    public func applicationDidFinishLaunching(_: Notification) {
        // Layer 1: Observer fires when the first window becomes key (visible + active).
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activateApp()
                self?.removeWindowObserver()
            }
        }

        // Layer 2: Deferred fallback in case the window takes longer to appear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            Task { @MainActor [weak self] in
                self?.activateApp()
                self?.removeWindowObserver()
            }
        }
    }

    public func applicationShouldHandleReopen(
        _: NSApplication,
        hasVisibleWindows _: Bool
    ) -> Bool {
        true
    }

    private func activateApp() {
        guard let window = NSApp.windows.first(where: { win in
            win.isVisible || win.canBecomeMain
        })
        else {
            return
        }
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func removeWindowObserver() {
        guard let observer = windowObserver else { return }
        NotificationCenter.default.removeObserver(observer)
        windowObserver = nil
    }
}
