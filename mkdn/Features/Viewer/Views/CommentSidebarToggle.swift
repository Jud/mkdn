#if os(macOS)
    import SwiftUI

    /// The floating affordance that toggles the comment sidebar, shown top-right of
    /// the content (the window is chrome-less, so there's no toolbar to host it).
    /// It stays put in both states — the rail slides in underneath it — so the
    /// same click point opens and closes the drawer; `isOpen` tints it active.
    /// With no comments it's a bare circle; once there are comments it carries a
    /// count. The hotkey (⌘⇧C) is intentionally not surfaced here.
    struct CommentSidebarToggle: View {
        let count: Int
        let isOpen: Bool
        let theme: AppTheme
        let action: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private static let diameter: CGFloat = 34

        private var motion: MotionPreference {
            MotionPreference(reduceMotion: reduceMotion)
        }

        var body: some View {
            Button(action: action) {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 13, weight: .medium))
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption.weight(.semibold))
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .foregroundStyle(isOpen ? theme.colors.accent : theme.colors.foregroundSecondary)
                .padding(.horizontal, count > 0 ? 11 : 0)
                // A minWidth floor (vs a fixed width) keeps both states
                // intrinsic-driven, so the circle↔pill morph animates smoothly
                // instead of snapping between a fixed and a hugging width.
                .frame(minWidth: Self.diameter, minHeight: Self.diameter)
                .background(theme.colors.backgroundSecondary)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(theme.colors.border.opacity(DesignTokens.Stroke.resting)))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                .animation(motion.resolved(.gentleSpring), value: count)
                .animation(motion.resolved(.gentleSpring), value: isOpen)
            }
            .buttonStyle(.plain)
            // A real AppKit cursor rect, not `pointingHandCursor()`: the toggle
            // floats over the text view, where AppKit's cursorUpdate pass resets
            // the SwiftUI-hover-set cursor to the arrow on every mouse move.
            .background(HandCursorRect())
            .accessibilityLabel(
                isOpen ? "Hide comments" : (count > 0 ? "Comments (\(count))" : "Comments")
            )
        }
    }

    /// Pointing-hand cursor via an AppKit cursor rect. Hit-test transparent, so
    /// clicks pass through to the SwiftUI button above; the cursor rect itself is
    /// window-managed geometry and works regardless.
    private struct HandCursorRect: NSViewRepresentable {
        final class CursorRectView: NSView {
            override func resetCursorRects() {
                addCursorRect(bounds, cursor: .pointingHand)
            }

            override func hitTest(_: NSPoint) -> NSView? { nil }
        }

        func makeNSView(context _: Context) -> CursorRectView { CursorRectView() }

        func updateNSView(_ view: CursorRectView, context _: Context) {
            view.window?.invalidateCursorRects(for: view)
        }
    }
#endif
