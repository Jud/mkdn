import SwiftUI

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

        CommandGroup(after: .sidebar) {
            Section {
                Button("Preview Only") {
                    appState.viewMode = .previewOnly
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Edit + Preview") {
                    appState.viewMode = .sideBySide
                }
                .keyboardShortcut("2", modifiers: .command)
            }
        }

        CommandGroup(after: .importExport) {
            Button("Reload File") {
                try? appState.reloadFile()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(appState.currentFileURL == nil)
        }
    }
}
