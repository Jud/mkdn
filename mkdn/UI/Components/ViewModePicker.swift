import SwiftUI

/// Toolbar picker for switching between preview-only and side-by-side modes.
struct ViewModePicker: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Picker("Mode", selection: $state.viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}
