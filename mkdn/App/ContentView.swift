import SwiftUI
import UniformTypeIdentifiers

/// Root content view that switches between preview-only and side-by-side modes.
/// Overlays a unified stateful orb indicator and an ephemeral mode label.
/// Bridges the system `colorScheme` environment to `AppSettings` for auto-theming.
public struct ContentView: View {
    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings
    @Environment(FindState.self) private var findState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    public init() {}

    public var body: some View {
        ZStack {
            Group {
                if documentState.currentFileURL == nil {
                    WelcomeView()
                } else {
                    switch documentState.viewMode {
                    case .previewOnly:
                        MarkdownPreviewView()
                            .transition(.opacity)
                    case .sideBySide:
                        SplitEditorView()
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
            }
            .animation(motion.resolved(.gentleSpring), value: documentState.viewMode)

            TheOrbView()

            if let label = documentState.modeOverlayLabel {
                ModeTransitionOverlay(label: label) {
                    documentState.modeOverlayLabel = nil
                }
                .id(label)
            }

            FindBarView()
                .allowsHitTesting(findState.isVisible)
                .accessibilityHidden(!findState.isVisible)
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(appSettings.theme.colors.background)
        .background(WindowAccessor())
        .onAppear {
            appSettings.systemColorScheme = colorScheme
        }
        .onChange(of: colorScheme) { _, newScheme in
            let themeAnimation = reduceMotion
                ? AnimationConstants.reducedCrossfade
                : AnimationConstants.crossfade
            withAnimation(themeAnimation) {
                appSettings.systemColorScheme = newScheme
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, url.pathExtension == "md" || url.pathExtension == "markdown" else {
                return
            }
            Task { @MainActor in
                try? documentState.loadFile(at: url)
            }
        }
        return true
    }
}
