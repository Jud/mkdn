import SwiftUI

/// Environment key indicating whether the current view hierarchy is in
/// directory mode (sidebar visible). Defaults to `false` for backward
/// compatibility with single-file windows.
///
/// Set by ``DirectoryContentView`` and read by ``WelcomeView`` to
/// display an appropriate welcome message.
private struct DirectoryModeKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var isDirectoryMode: Bool {
        get { self[DirectoryModeKey.self] }
        set { self[DirectoryModeKey.self] = newValue }
    }
}
