import SwiftUI

/// Three-segment picker for switching theme modes: Auto, Dark, Light.
struct ThemePickerView: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var settings = appSettings

        Picker("Theme", selection: $settings.themeMode) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
