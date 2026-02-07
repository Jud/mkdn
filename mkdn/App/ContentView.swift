import SwiftUI
import UniformTypeIdentifiers

/// Root content view that switches between preview-only and side-by-side modes.
/// Overlays a breathing orb for file-change notification and an ephemeral mode label.
/// Bridges the system `colorScheme` environment to `AppState` for auto-theming.
public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        ZStack {
            Group {
                if appState.currentFileURL == nil {
                    WelcomeView()
                } else {
                    switch appState.viewMode {
                    case .previewOnly:
                        MarkdownPreviewView()
                            .transition(.opacity)
                    case .sideBySide:
                        SplitEditorView()
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
            }
            .animation(AnimationConstants.viewModeTransition, value: appState.viewMode)

            if appState.isFileOutdated {
                BreathingOrbView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(16)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(AnimationConstants.orbAppear),
                            removal: .scale(scale: 0.5)
                                .combined(with: .opacity)
                                .animation(AnimationConstants.orbDissolve)
                        )
                    )
            }

            if let label = appState.modeOverlayLabel {
                ModeTransitionOverlay(label: label) {
                    appState.modeOverlayLabel = nil
                }
                .id(label)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            appState.systemColorScheme = colorScheme
        }
        .onChange(of: colorScheme) { _, newScheme in
            appState.systemColorScheme = newScheme
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
                try? appState.loadFile(at: url)
            }
        }
        return true
    }
}
