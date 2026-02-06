import SwiftUI
import UniformTypeIdentifiers

/// Application menu commands.
public struct MkdnCommands: Commands {
    public let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                try? appState.saveFile()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(appState.currentFileURL == nil || !appState.hasUnsavedChanges)
        }

        CommandGroup(after: .importExport) {
            Button("Open...") {
                openFile()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Reload") {
                try? appState.reloadFile()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(appState.currentFileURL == nil || !appState.isFileOutdated)
        }

        CommandGroup(after: .sidebar) {
            Section {
                Button("Preview Mode") {
                    appState.switchMode(to: .previewOnly)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Edit Mode") {
                    appState.switchMode(to: .sideBySide)
                }
                .keyboardShortcut("2", modifiers: .command)
            }

            Section {
                Button("Cycle Theme") {
                    withAnimation(AnimationConstants.themeCrossfade) {
                        appState.cycleTheme()
                    }
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }

    @MainActor
    private func openFile() {
        let panel = NSOpenPanel()
        if let mdType = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [mdType]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? appState.loadFile(at: url)
    }
}
