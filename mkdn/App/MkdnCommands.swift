import SwiftUI
import UniformTypeIdentifiers

/// Application menu commands.
///
/// Uses `AppSettings` for theme operations and `@FocusedValue` to access
/// the active window's `DocumentState` for document operations.
public struct MkdnCommands: Commands {
    public let appSettings: AppSettings
    @FocusedValue(\.documentState) private var documentState
    @FocusedValue(\.findState) private var findState

    public init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }

    public var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About mkdn") {
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationIcon: NSApp.applicationIconImage as Any,
                ])
            }
        }

        CommandGroup(after: .appInfo) {
            Button("Set as Default Markdown App") {
                let success = DefaultHandlerService.registerAsDefault()
                if success {
                    documentState?.modeOverlayLabel = "Default Markdown App Set"
                } else {
                    documentState?.modeOverlayLabel = "Could not set default — install mkdn.app first"
                }
            }
            .disabled(!DefaultHandlerService.canRegisterAsDefault)
        }

        CommandGroup(after: .newItem) {
            Button("Close") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                try? documentState?.saveFile()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(documentState?.currentFileURL == nil || documentState?.hasUnsavedChanges != true)

            Button("Save As...") {
                documentState?.saveAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(documentState == nil)
        }

        CommandGroup(after: .pasteboard) {
            Button("Find...") {
                withAnimation(motionAnimation(.springSettle)) {
                    findState?.show()
                }
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Find Next") {
                findState?.nextMatch()
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("Find Previous") {
                findState?.previousMatch()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button("Use Selection for Find") {
                guard let textView = Self.findTextView() else { return }
                let range = textView.selectedRange()
                guard range.length > 0,
                      let swiftRange = Range(range, in: textView.string)
                else { return }
                let selectedText = String(textView.string[swiftRange])
                withAnimation(motionAnimation(.springSettle)) {
                    findState?.useSelection(selectedText)
                }
            }
            .keyboardShortcut("e", modifiers: .command)
        }

        CommandGroup(replacing: .printItem) {
            Button("Page Setup...") {
                NSApp.sendAction(
                    #selector(NSDocument.runPageLayout(_:)),
                    to: nil,
                    from: nil
                )
            }
            .keyboardShortcut("P", modifiers: [.command, .shift])

            Button("Print...") {
                Self.findTextView()?.printView(nil)
            }
            .keyboardShortcut("p", modifiers: .command)
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

        CommandGroup(after: .toolbar) {
            Section {
                Button("Zoom In") {
                    appSettings.zoomIn()
                    documentState?.modeOverlayLabel = appSettings.zoomLabel
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    appSettings.zoomOut()
                    documentState?.modeOverlayLabel = appSettings.zoomLabel
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    appSettings.zoomReset()
                    documentState?.modeOverlayLabel = appSettings.zoomLabel
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }

        CommandGroup(after: .sidebar) {
            Section {
                Button("Toggle Sidebar") {
                    withAnimation(motionAnimation(.sidebarSlide)) {
                        documentState?.toggleSidebar()
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }

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
                    appSettings.cycleTheme()
                    documentState?.modeOverlayLabel = appSettings.themeMode.displayName
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }

    @MainActor
    static func findTextView() -> CodeBlockBackgroundTextView? {
        guard let contentView = NSApp.keyWindow?.contentView else { return nil }
        return findTextView(in: contentView)
    }

    private static func findTextView(in view: NSView) -> CodeBlockBackgroundTextView? {
        if let textView = view as? CodeBlockBackgroundTextView {
            return textView
        }
        for subview in view.subviews {
            if let found = findTextView(in: subview) {
                return found
            }
        }
        return nil
    }

    private func motionAnimation(_ primitive: MotionPreference.Primitive) -> Animation? {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        return MotionPreference(reduceMotion: reduceMotion).resolved(primitive)
    }

    @MainActor
    private func openFile() {
        let panel = NSOpenPanel()
        let extensions = [
            "md", "markdown",
            "swift", "py", "js", "ts", "rs", "go",
            "c", "cpp", "h", "hpp",
            "java", "rb", "json", "yaml", "yml",
            "html", "css", "sh", "kt",
            "toml", "xml", "sql", "r", "lua", "zig",
            "txt",
        ]
        var types: [UTType] = []
        for ext in extensions {
            if let utType = UTType(filenameExtension: ext), !types.contains(utType) {
                types.append(utType)
            }
        }
        if !types.isEmpty { panel.allowedContentTypes = types }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? documentState?.loadFile(at: url)
    }
}
