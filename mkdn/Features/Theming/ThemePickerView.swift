import SwiftUI

/// Three-segment picker for switching theme modes: Auto, Dark, Light.
/// Theme changes are wrapped with a crossfade animation to ensure smooth
/// transitions across the entire view hierarchy.
struct ThemePickerView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let themeBinding = Binding<ThemeMode>(
            get: { appSettings.themeMode },
            set: { newMode in
                let themeAnimation = reduceMotion
                    ? AnimationConstants.reducedCrossfade
                    : AnimationConstants.crossfade
                withAnimation(themeAnimation) {
                    appSettings.themeMode = newMode
                }
            }
        )

        Picker("Theme", selection: themeBinding) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
