import AppKit
import SwiftUI

/// Menu commands for the File > Open Recent submenu.
///
/// Reads ``NSDocumentController/recentDocumentURLs`` to build the menu
/// dynamically and routes selection through ``FileOpenCoordinator`` so
/// the active ``DocumentWindow`` opens a new window for the chosen file.
public struct OpenRecentCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Menu("Open Recent") {
                ForEach(
                    NSDocumentController.shared.recentDocumentURLs,
                    id: \.self
                ) { url in
                    Button(url.lastPathComponent) {
                        FileOpenCoordinator.shared.pendingURLs.append(url)
                    }
                }
                Divider()
                Button("Clear Menu") {
                    NSDocumentController.shared.clearRecentDocuments(nil)
                }
            }
        }
    }
}
