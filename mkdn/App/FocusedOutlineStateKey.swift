#if os(macOS)
    import SwiftUI

    /// Focused-value key for accessing the active window's `OutlineState`
    /// from menu commands and other scene-level code.
    public struct FocusedOutlineStateKey: FocusedValueKey {
        public typealias Value = OutlineState
    }

    public extension FocusedValues {
        var outlineState: OutlineState? {
            get { self[FocusedOutlineStateKey.self] }
            set { self[FocusedOutlineStateKey.self] = newValue }
        }
    }
#endif
