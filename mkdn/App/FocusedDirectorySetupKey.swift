#if os(macOS)
    import SwiftUI

    /// Focused-value key carrying a closure that sets up directory mode
    /// for the active window. Published by ``DocumentWindow`` so that
    /// menu commands can trigger "Open Directory" from any window.
    public struct FocusedDirectorySetupKey: FocusedValueKey {
        public typealias Value = (URL) -> Void
    }

    public extension FocusedValues {
        var directorySetup: ((URL) -> Void)? {
            get { self[FocusedDirectorySetupKey.self] }
            set { self[FocusedDirectorySetupKey.self] = newValue }
        }
    }
#endif
