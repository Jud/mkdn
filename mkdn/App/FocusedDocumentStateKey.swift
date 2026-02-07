import SwiftUI

/// Focused-value key for accessing the active window's `DocumentState`
/// from menu commands and other scene-level code.
public struct FocusedDocumentStateKey: FocusedValueKey {
    public typealias Value = DocumentState
}

public extension FocusedValues {
    var documentState: DocumentState? {
        get { self[FocusedDocumentStateKey.self] }
        set { self[FocusedDocumentStateKey.self] = newValue }
    }
}
