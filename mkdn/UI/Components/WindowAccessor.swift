import AppKit
import Carbon
import SwiftUI

/// Transparent NSView helper that configures the hosting NSWindow
/// to remove the title bar compositing layer (which covers scrolled content)
/// while preserving rounded corners, window dragging, and resizability.
public struct WindowAccessor: NSViewRepresentable {
    public init() {}

    public func makeNSView(context _: Context) -> WindowAccessorView {
        WindowAccessorView()
    }

    public func updateNSView(_: WindowAccessorView, context _: Context) {}
}

/// Custom NSView that configures its hosting window when attached.
public final class WindowAccessorView: NSView {
    private var didConfigure = false

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, !didConfigure else { return }
        didConfigure = true

        // Defer style mask changes to avoid crashing during the initial
        // layout pass (removing .titled triggers a relayout).
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            self.configureWindow(window)
        }
    }

    @objc private func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let size = window.frame.size
        UserDefaults.standard.set(Double(size.width), forKey: "windowWidth")
        UserDefaults.standard.set(Double(size.height), forKey: "windowHeight")
    }

    private func configureWindow(_ window: NSWindow) {
        // Keep .titled for proper key window tracking and @FocusedValue
        // support. Hide the title bar visually and extend content underneath.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.miniaturizable)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.backgroundColor = .clear

        // Apply the user's saved window size. .defaultSize() on the
        // WindowGroup only applies reliably to the first window; subsequent
        // windows opened via openWindow(value:) may ignore it.
        let savedWidth = UserDefaults.standard.double(forKey: "windowWidth")
        let savedHeight = UserDefaults.standard.double(forKey: "windowHeight")
        if savedWidth > 0, savedHeight > 0 {
            var frame = window.frame
            frame.size = NSSize(width: savedWidth, height: savedHeight)
            window.setFrame(frame, display: true)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )

        guard !TestHarnessMode.isEnabled else { return }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if IsSecureEventInputEnabled() {
            EnableSecureEventInput()
            NSApp.activate()
            DisableSecureEventInput()
        } else {
            NSApp.activate()
        }
    }
}
