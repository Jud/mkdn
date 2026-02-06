import mkdnLib
import SwiftUI

// MARK: - SwiftUI App (no @main)

struct MkdnApp: App {
    @State private var appState: AppState

    init() {
        let state = AppState()
        if let url = LaunchContext.fileURL {
            try? state.loadFile(at: url)
        }
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            MkdnCommands(appState: appState)
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

    MkdnApp.main()
} catch let error as CLIError {
    FileHandle.standardError.write(
        Data("mkdn: error: \(error.localizedDescription)\n".utf8)
    )
    Foundation.exit(error.exitCode)
} catch {
    MkdnCLI.exit(withError: error)
}
