import AppKit

/// Handles system file-open events and routes them through ``FileOpenCoordinator``.
///
/// Wired into the SwiftUI lifecycle via `@NSApplicationDelegateAdaptor(AppDelegate.self)`.
/// Intercepts `kAEOpenDocuments` AppleEvents before SwiftUI sees them so that
/// Finder file-open events are routed through ``LaunchContext`` (cold launch) or
/// ``FileOpenCoordinator`` (warm launch) without suppressing default window creation.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didFinishLaunching = false

    public func applicationWillFinishLaunching(_: Notification) {
        // Install before NSDocumentController.shared is ever accessed so the
        // subclass becomes the shared controller, suppressing document-class
        // lookup errors for Markdown file-open events.
        _ = NonDocumentController()

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

        if !LaunchContext.fileURLs.isEmpty {
            DispatchQueue.main.async {
                let hasVisibleWindow = NSApp.windows.contains(where: \.isVisible)
                if !hasVisibleWindow {
                    _ = try? NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
                }
            }
        }
    }

    @objc private func handleOpenDocuments(
        _ event: NSAppleEventDescriptor,
        withReply _: NSAppleEventDescriptor
    ) {
        guard let listDesc = event.paramDescriptor(forKeyword: keyDirectObject) else { return }

        var urls: [URL] = []
        for index in 1 ... listDesc.numberOfItems {
            guard let itemDesc = listDesc.atIndex(index),
                  let data = itemDesc.coerce(toDescriptorType: typeFileURL)?.data,
                  let urlString = String(data: data, encoding: .utf8),
                  let url = URL(string: urlString)
            else { continue }
            urls.append(url)
        }

        let markdownURLs = urls.filter { FileOpenCoordinator.isMarkdownURL($0) }
        guard !markdownURLs.isEmpty else { return }

        for url in markdownURLs {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }

        if didFinishLaunching {
            for url in markdownURLs {
                FileOpenCoordinator.shared.pendingURLs.append(url)
            }
        } else {
            LaunchContext.fileURLs = markdownURLs
        }
    }

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
            NSApp.keyWindow?.close()
            return nil
        }
    }

    /// Applies macOS-style icon treatment: drop shadow, squircle mask, and inner stroke.
    private static func applyIconMask(to image: NSImage) -> NSImage {
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
