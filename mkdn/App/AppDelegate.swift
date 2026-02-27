import AppKit

/// Handles system file-open events and routes them through ``FileOpenCoordinator``.
///
/// Wired into the SwiftUI lifecycle via `@NSApplicationDelegateAdaptor(AppDelegate.self)`.
/// On cold launch, Finder file-open events are intercepted via a `kAEOpenDocuments`
/// AppleEvent handler that stores URLs in ``LaunchContext`` and restarts the app
/// without the event (same strategy as the CLI/execv path in `main.swift`).
/// On warm launch, `application(_:open:)` routes through ``FileOpenCoordinator``.
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
        // FileOpenCoordinator via the pendingURLs queue.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocuments(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )

        guard !TestHarnessMode.isEnabled else { return }
        NSApp.setActivationPolicy(.regular)

        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL)
        {
            NSApp.applicationIconImage = Self.applyIconMask(to: icon)
        }
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
        let markdownURLs = urls.filter { FileOpenCoordinator.isMarkdownURL($0) }
        guard !markdownURLs.isEmpty else { return }

        for url in markdownURLs {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }

        let hasVisibleWindows = didFinishLaunching
            && NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }

        if hasVisibleWindows {
            // Warm launch with windows: existing DocumentWindow observers
            // pick these up via onChange(of: pendingURLs).
            for url in markdownURLs {
                FileOpenCoordinator.shared.pendingURLs.append(url)
            }
        } else {
            // Cold launch OR warm launch with no windows: store URLs in the
            // env var and re-exec so SwiftUI launches clean with a default
            // window. consumeLaunchContext() picks up the URLs.
            let pathString = markdownURLs.map(\.path).joined(separator: "\n")
            setenv("MKDN_LAUNCH_FILE", pathString, 1)

            let execPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
            let cArgs: [UnsafeMutablePointer<CChar>?] = [strdup(execPath), nil]
            cArgs.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                _ = execv(execPath, baseAddress)
            }
            // execv only returns on failure — fall back to pendingURLs
            for url in markdownURLs {
                FileOpenCoordinator.shared.pendingURLs.append(url)
            }
        }
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

    /// Applies macOS-style icon treatment: drop shadow, squircle mask, and inner stroke.
    static func applyIconMask(to image: NSImage) -> NSImage {
        let canvasSize = NSSize(width: 1_024, height: 1_024)
        let result = NSImage(size: canvasSize)
        result.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            result.unlockFocus()
            return image
        }

        // Icon grid: artwork ~824x824, shifted up slightly to leave room for shadow below
        let inset = canvasSize.width * 0.1
        let shadowOffset: CGFloat = 6
        let iconRect = NSRect(
            x: inset,
            y: inset + shadowOffset,
            width: canvasSize.width - inset * 2,
            height: canvasSize.height - inset * 2
        )
        let radius = iconRect.width * 0.2237
        let shapePath = NSBezierPath(roundedRect: iconRect, xRadius: radius, yRadius: radius)

        // Drop shadow
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -10),
            blur: 20,
            color: NSColor.black.withAlphaComponent(0.5).cgColor
        )
        NSColor.black.setFill()
        shapePath.fill()
        context.restoreGState()

        // Clipped icon artwork
        context.saveGState()
        shapePath.addClip()
        image.draw(in: iconRect, from: .zero, operation: .copy, fraction: 1.0)
        context.restoreGState()

        // Inner stroke (subtle dark border like macOS applies)
        context.saveGState()
        shapePath.lineWidth = 2.0
        NSColor.black.withAlphaComponent(0.15).setStroke()
        shapePath.stroke()
        context.restoreGState()

        result.unlockFocus()
        result.isTemplate = false
        return result
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
