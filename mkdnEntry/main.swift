import AppKit
import mkdnLib
import SwiftUI

// MARK: - SwiftUI App (no @main)

struct MkdnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup(for: URL.self) { $fileURL in
            DocumentWindow(fileURL: fileURL)
                .environment(appSettings)
        }
        .handlesExternalEvents(matching: [])
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            MkdnCommands(appSettings: appSettings)
            OpenRecentCommands()
        }
    }
}

// MARK: - CLI Entry Point

do {
    let cli = try MkdnCLI.parse()

    if let filePath = cli.file {
        let url = try FileValidator.validate(path: filePath)
        LaunchContext.fileURL = url
    }

    // Strip CLI arguments so SwiftUI only sees the bare executable name.
    // Without this, WindowGroup(for: URL.self) misinterprets the file argument
    // and fails to create its default window.
    CommandLine.arguments = [CommandLine.arguments[0]]

    NSApplication.shared.setActivationPolicy(.regular)
    MkdnApp.main()
    // Note: MkdnApp.main() never returns (runs the app loop)
} catch let error as CLIError {
    FileHandle.standardError.write(
        Data("mkdn: error: \(error.localizedDescription)\n".utf8)
    )
    Foundation.exit(error.exitCode)
} catch {
    MkdnCLI.exit(withError: error)
}
