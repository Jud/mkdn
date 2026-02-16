import SwiftUI

/// Focused-value key for accessing the active window's `FindState`
/// from menu commands and other scene-level code.
public struct FocusedFindStateKey: FocusedValueKey {
    public typealias Value = FindState
}

public extension FocusedValues {
    var findState: FindState? {
        get { self[FocusedFindStateKey.self] }
        set { self[FocusedFindStateKey.self] = newValue }
    }
}
