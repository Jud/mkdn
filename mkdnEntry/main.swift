import SwiftUI
import mkdnLib

@main
struct MkdnApp: App {
    @State private var appState = AppState()

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
