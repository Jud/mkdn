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

    private func configureWindow(_ window: NSWindow) {
        let previousFrame = window.frame
        window.styleMask.remove(.titled)
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.miniaturizable)
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.backgroundColor = .clear

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 10
            contentView.layer?.masksToBounds = true
        }

        window.setFrame(previousFrame, display: true)

        guard !TestHarnessMode.isEnabled else { return }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if IsSecureEventInputEnabled() {
            EnableSecureEventInput()
            NSApp.activate(ignoringOtherApps: true)
            DisableSecureEventInput()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
