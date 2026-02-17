import SwiftUI

/// Top-level layout wrapper that places the sidebar alongside the existing
/// ``ContentView`` using an HStack-based layout (per CON-3: no
/// NavigationSplitView).
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

    var body: some View {
        HStack(spacing: 0) {
            if directoryState.isSidebarVisible {
                SidebarView()
                    .frame(width: directoryState.sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                SidebarDivider()
            }

            ContentView()
        }
        .environment(\.isDirectoryMode, true)
        .animation(motion.resolved(.gentleSpring), value: directoryState.isSidebarVisible)
        .frame(minWidth: 600, minHeight: 400)
    }
}
