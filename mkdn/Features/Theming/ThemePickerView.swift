import SwiftUI

/// Picker for switching between available themes.
struct ThemePickerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Picker("Theme", selection: $state.theme) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Text(theme.rawValue).tag(theme)
            }
        }
        .pickerStyle(.segmented)
    }
}
