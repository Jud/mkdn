import AppKit
import SwiftUI

/// NSView that prevents `isMovableByWindowBackground` from stealing drags.
private final class DragBlockingView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }

    override var isOpaque: Bool { false }

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
/// Clamps the sidebar width within ``DirectoryState/minSidebarWidth``
/// and ``DirectoryState/maxSidebarWidth``.
struct SidebarDivider: View {
    @Environment(DirectoryState.self) private var directoryState
    @Environment(AppSettings.self) private var appSettings

    @State private var dragStartWidth: CGFloat?

    var body: some View {
        DragBlocker()
            .frame(width: 8)
            .background(appSettings.theme.colors.backgroundSecondary)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if dragStartWidth == nil {
                            dragStartWidth = directoryState.sidebarWidth
                        }
                        let newWidth = (dragStartWidth ?? directoryState.sidebarWidth) + value.translation.width
                        directoryState.sidebarWidth = min(
                            max(newWidth, DirectoryState.minSidebarWidth),
                            DirectoryState.maxSidebarWidth
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
