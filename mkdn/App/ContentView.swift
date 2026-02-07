import SwiftUI
import UniformTypeIdentifiers

/// Root content view that switches between preview-only and side-by-side modes.
/// Overlays a breathing orb for file-change notification and an ephemeral mode label.
/// Bridges the system `colorScheme` environment to `AppSettings` for auto-theming.
public struct ContentView: View {
    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.colorScheme) private var colorScheme

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
            .animation(AnimationConstants.viewModeTransition, value: documentState.viewMode)

            if documentState.isFileOutdated {
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

            if let label = documentState.modeOverlayLabel {
                ModeTransitionOverlay(label: label) {
                    documentState.modeOverlayLabel = nil
                }
                .id(label)
            }

            if !appSettings.hasShownDefaultHandlerHint {
                DefaultHandlerHintView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 8)
                    .padding(.trailing, 12)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(WindowAccessor())
        .onAppear {
            appSettings.systemColorScheme = colorScheme
        }
        .onChange(of: colorScheme) { _, newScheme in
            appSettings.systemColorScheme = newScheme
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
