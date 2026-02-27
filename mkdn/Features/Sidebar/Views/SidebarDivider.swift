import AppKit
import SwiftUI

/// NSView that prevents `isMovableByWindowBackground` from stealing drags.
private final class DragBlockingView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override var isOpaque: Bool {
        false
    }

    override func draw(_: NSRect) {}
}

/// Wraps ``DragBlockingView`` so the sidebar divider isn't treated as
/// window-draggable background.
private struct DragBlocker: NSViewRepresentable {
    func makeNSView(context _: Context) -> DragBlockingView {
        DragBlockingView()
    }

    func updateNSView(_: DragBlockingView, context _: Context) {}
}

/// Draggable divider between the sidebar and content area.
///
/// Uses an 8pt-wide hit target backed by an AppKit view that returns
/// `mouseDownCanMoveWindow = false`, preventing the window drag handler
/// from intercepting resize drags.
/// Clamps the sidebar width within ``DocumentState/minSidebarWidth``
/// and ``DocumentState/maxSidebarWidth``.
struct SidebarDivider: View {
    static let width: CGFloat = 8

    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings

    @State private var dragStartWidth: CGFloat?

    var body: some View {
        DragBlocker()
            .frame(width: Self.width)
            .background(appSettings.theme.colors.backgroundSecondary)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if dragStartWidth == nil {
                            dragStartWidth = documentState.sidebarWidth
                        }
                        let newWidth = (dragStartWidth ?? documentState.sidebarWidth) + value.translation.width
                        documentState.sidebarWidth = min(
                            max(newWidth, DocumentState.minSidebarWidth),
                            DocumentState.maxSidebarWidth
                        )
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
