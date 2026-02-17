import SwiftUI

/// Draggable divider between the sidebar and content area.
///
/// Provides a 1pt visual line with a wider hit target for drag resizing.
/// Clamps the sidebar width within ``DirectoryState/minSidebarWidth``
/// and ``DirectoryState/maxSidebarWidth``.
struct SidebarDivider: View {
    @Environment(DirectoryState.self) private var directoryState
    @Environment(AppSettings.self) private var appSettings

    @State private var dragStartWidth: CGFloat?

    var body: some View {
        Rectangle()
            .fill(appSettings.theme.colors.border)
            .frame(width: 1)
            .contentShape(Rectangle().inset(by: -3))
            .gesture(
                DragGesture(minimumDistance: 1)
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
