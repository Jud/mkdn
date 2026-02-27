import AppKit
import SwiftUI

/// Sets the hosting NSWindow's background color so that clipped SwiftUI
/// views reveal the correct color rather than the system default.
private struct WindowBackgroundColor: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context _: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            nsView.window?.backgroundColor = color
        }
    }
}

/// Top-level layout wrapper that places the sidebar behind the content view
/// using a drawer pattern (per CON-3: no NavigationSplitView).
///
/// When the sidebar is toggled, the content view slides right to reveal the
/// sidebar underneath. The window frame stays fixed — only the content moves.
///
/// Manages animated sidebar show/hide using `gentleSpring` via
/// ``MotionPreference``, respecting the system Reduce Motion preference.
/// Sets the `isDirectoryMode` environment key so that ``WelcomeView`` can
/// display an appropriate directory-mode message.
struct DirectoryContentView: View {
    @Environment(DirectoryState.self) private var directoryState
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    private var sidebarOffset: CGFloat {
        directoryState.isSidebarVisible
            ? directoryState.sidebarWidth + SidebarDivider.width
            : 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    SidebarView()
                        .frame(width: directoryState.sidebarWidth)

                    SidebarDivider()
                }

                ContentView()
                    .frame(width: geometry.size.width - sidebarOffset)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: directoryState.isSidebarVisible ? 10 : 0,
                            bottomLeadingRadius: directoryState.isSidebarVisible ? 10 : 0
                        )
                    )
                    .offset(x: sidebarOffset)
            }
        }
        .background(
            WindowBackgroundColor(
                color: NSColor(appSettings.theme.colors.backgroundSecondary)
            )
        )
        .environment(\.isDirectoryMode, true)
        .animation(motion.resolved(.gentleSpring), value: directoryState.isSidebarVisible)
        .animation(motion.resolved(.gentleSpring), value: directoryState.sidebarWidth)
        .ignoresSafeArea()
        .frame(minWidth: 600, minHeight: 400)
    }
}
