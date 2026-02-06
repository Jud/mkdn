import SwiftUI

/// Snaps a proposed split ratio to the nearest snap point when within a pixel threshold.
///
/// - Parameters:
///   - proposedRatio: The raw ratio from the drag gesture (0.0 to 1.0).
///   - totalWidth: The total available width in points.
///   - snapPoints: Ratios to snap to (default: 0.3, 0.5, 0.7).
///   - snapThreshold: Pixel distance within which snapping occurs (default: 20pt).
///   - minPaneWidth: Minimum width for each pane in points (default: 200pt).
/// - Returns: The clamped and optionally snapped ratio.
func snappedSplitRatio(
    proposedRatio: CGFloat,
    totalWidth: CGFloat,
    snapPoints: [CGFloat] = [0.3, 0.5, 0.7],
    snapThreshold: CGFloat = 20,
    minPaneWidth: CGFloat = 200
) -> CGFloat {
    guard totalWidth > 0 else { return 0.5 }

    let minRatio = minPaneWidth / totalWidth
    let maxRatio = 1.0 - minRatio
    let clamped = min(max(proposedRatio, minRatio), max(maxRatio, minRatio))

    let proposedPosition = clamped * totalWidth
    for point in snapPoints {
        let snapPosition = point * totalWidth
        if abs(proposedPosition - snapPosition) <= snapThreshold {
            return point
        }
    }

    return clamped
}

/// A resizable split view with a draggable divider, snap points, and hover feedback.
///
/// Presents two panes side-by-side separated by a divider bar the user can drag
/// to resize. The divider snaps to preset ratio points when dragged near them and
/// provides visual feedback on hover.
struct ResizableSplitView<Left: View, Right: View>: View {
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    @State private var splitRatio: CGFloat = 0.5
    @State private var dragStartRatio: CGFloat = 0.5
    @State private var isDragging = false
    @State private var isHovering = false

    private let dividerIdleWidth: CGFloat = 6
    private let dividerHoverWidth: CGFloat = 10
    private let minPaneWidth: CGFloat = 200

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let effectiveDividerWidth = isHovering || isDragging ? dividerHoverWidth : dividerIdleWidth
            let availableWidth = totalWidth - effectiveDividerWidth
            let leftWidth = max(availableWidth * splitRatio, 0)
            let rightWidth = max(availableWidth - leftWidth, 0)

            HStack(spacing: 0) {
                left()
                    .frame(width: leftWidth)

                divider(totalWidth: totalWidth)
                    .frame(width: effectiveDividerWidth)

                right()
                    .frame(width: rightWidth)
            }
        }
    }

    private func divider(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(dividerFill)
            .contentShape(Rectangle())
            .gesture(dragGesture(totalWidth: totalWidth))
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    private var dividerFill: some ShapeStyle {
        if isDragging {
            AnyShapeStyle(Color.accentColor.opacity(0.6))
        } else if isHovering {
            AnyShapeStyle(Color.accentColor.opacity(0.35))
        } else {
            AnyShapeStyle(Color.gray.opacity(0.2))
        }
    }

    private func dragGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartRatio = splitRatio
                }
                let dividerWidth = dividerHoverWidth
                let availableWidth = totalWidth - dividerWidth
                guard availableWidth > 0 else { return }
                let startLeftWidth = availableWidth * dragStartRatio
                let newLeftWidth = startLeftWidth + value.translation.width
                let rawRatio = newLeftWidth / availableWidth
                splitRatio = snappedSplitRatio(
                    proposedRatio: rawRatio,
                    totalWidth: availableWidth,
                    minPaneWidth: minPaneWidth
                )
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}
