import SwiftUI
import UniformTypeIdentifiers

/// Application menu commands.
///
/// Uses `AppSettings` for theme operations and `@FocusedValue` to access
/// the active window's `DocumentState` for document operations.
public struct MkdnCommands: Commands {
    public let appSettings: AppSettings
    @FocusedValue(\.documentState) private var documentState

    public init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }

    public var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Set as Default Markdown App") {
                let success = DefaultHandlerService.registerAsDefault()
                if success {
                    documentState?.modeOverlayLabel = "Default Markdown App Set"
                }
            }
        }

        CommandGroup(before: .saveItem) {
            Button("Close Window") {
                NSApplication.shared.keyWindow?.close()
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                try? documentState?.saveFile()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(documentState?.currentFileURL == nil || documentState?.hasUnsavedChanges != true)
        }

        CommandGroup(after: .importExport) {
            Button("Open...") {
                openFile()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Reload") {
                try? documentState?.reloadFile()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(documentState?.currentFileURL == nil || documentState?.isFileOutdated != true)
        }

        CommandGroup(after: .sidebar) {
            Section {
                Button("Preview Mode") {
                    documentState?.switchMode(to: .previewOnly)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Edit Mode") {
                    documentState?.switchMode(to: .sideBySide)
                }
                .keyboardShortcut("2", modifiers: .command)
            }

            Section {
                Button("Cycle Theme") {
                    withAnimation(AnimationConstants.themeCrossfade) {
                        appSettings.cycleTheme()
                    }
                    documentState?.modeOverlayLabel = appSettings.themeMode.displayName
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
        try? documentState?.loadFile(at: url)
    }
}
