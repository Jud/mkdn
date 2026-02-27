import AppKit

/// Handles system file-open events and routes them through ``FileOpenService``.
///
/// Wired into the SwiftUI lifecycle via `@NSApplicationDelegateAdaptor(AppDelegate.self)`.
/// This is a thin delegate that extracts URLs from AppleEvents and delegates all
/// routing logic to ``FileOpenService/handleOpenDocuments(urls:didFinishLaunching:hasVisibleWindows:)``.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Tracks whether the app has fully launched. Used to distinguish cold
    /// launch (kAEOpenDocuments during startup) from warm launch (file opened
    /// while app is already running).
    private var didFinishLaunching = false

    public func applicationWillFinishLaunching(_: Notification) {
        // Install before NSDocumentController.shared is ever accessed so the
        // subclass becomes the shared controller, suppressing document-class
        // lookup errors for Markdown file-open events.
        _ = NonDocumentController()

        // Intercept kAEOpenDocuments before NSApplication's default handler.
        // On cold launch this prevents the event from suppressing SwiftUI's
        // default window creation. On warm launch the handler delegates to
        // FileOpenService via the pendingURLs queue.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocuments(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )

        guard !TestHarnessMode.isEnabled else { return }
        NSApp.setActivationPolicy(.regular)
    }

    public func applicationDidFinishLaunching(_: Notification) {
        didFinishLaunching = true
        installCloseWindowMonitor()
    }

    // MARK: - kAEOpenDocuments Handler

    @objc private func handleOpenDocuments(
        _ event: NSAppleEventDescriptor,
        withReply _: NSAppleEventDescriptor
    ) {
        let urls = extractURLs(from: event)
        let hasVisibleWindows = didFinishLaunching
            && NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }

        FileOpenService.shared.handleOpenDocuments(
            urls: urls,
            didFinishLaunching: didFinishLaunching,
            hasVisibleWindows: hasVisibleWindows
        )
    }

    private func extractURLs(from event: NSAppleEventDescriptor) -> [URL] {
        guard let listDesc = event.paramDescriptor(forKeyword: keyDirectObject) else {
            return []
        }
        var urls: [URL] = []
        for index in 1 ... max(listDesc.numberOfItems, 1) {
            let desc = listDesc.numberOfItems > 0 ? listDesc.atIndex(index) : listDesc
            guard let desc,
                  let data = desc.coerce(toDescriptorType: typeFileURL)?.data,
                  let urlString = String(data: data, encoding: .utf8),
                  let url = URL(string: urlString)
            else { continue }
            urls.append(url)
        }
        return urls
    }

    // MARK: - Window Management

    /// Installs a local event monitor that handles Cmd-W to close the key window.
    ///
    /// A local event monitor intercepts the keystroke before the menu system,
    /// guaranteeing Cmd-W works regardless of SwiftUI menu state.
    private func installCloseWindowMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers == "w"
            else {
                return event
            }
            if let keyWindow = NSApp.keyWindow {
                keyWindow.close()
            } else if let frontWindow = NSApp.orderedWindows.first(where: {
                $0.isVisible && !($0 is NSPanel)
            }) {
                frontWindow.close()
            }
            return nil
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    public func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        guard !TestHarnessMode.isEnabled else { return false }
        if hasVisibleWindows {
            sender.activate()
            sender.keyWindow?.makeKeyAndOrderFront(nil)
            return true
        }
        return false
    }
}
