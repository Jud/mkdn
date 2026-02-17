import SwiftUI

/// Focused-value key for accessing the active window's `DirectoryState`
/// from menu commands and other scene-level code.
public struct FocusedDirectoryStateKey: FocusedValueKey {
    public typealias Value = DirectoryState
}

public extension FocusedValues {
    var directoryState: DirectoryState? {
        get { self[FocusedDirectoryStateKey.self] }
        set { self[FocusedDirectoryStateKey.self] = newValue }
    }
}
