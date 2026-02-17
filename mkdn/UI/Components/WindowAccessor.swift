import AppKit
import Carbon
import SwiftUI

/// Transparent NSView helper that configures the hosting NSWindow
/// to hide all chrome (traffic light buttons, title visibility) while
/// keeping the window draggable by its background and fully resizable.
public struct WindowAccessor: NSViewRepresentable {
    public init() {}

    public func makeNSView(context _: Context) -> WindowAccessorView {
        WindowAccessorView()
    }

    public func updateNSView(_: WindowAccessorView, context _: Context) {}
}

/// Custom NSView that configures its hosting window when attached.
public final class WindowAccessorView: NSView {
    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        configureWindow(window)
    }

    private func configureWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        guard !TestHarnessMode.isEnabled else { return }
        DispatchQueue.main.async {
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
}
