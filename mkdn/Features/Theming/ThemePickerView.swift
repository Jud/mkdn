import SwiftUI

/// Three-segment picker for switching theme modes: Auto, Dark, Light.
struct ThemePickerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Picker("Theme", selection: $state.themeMode) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
