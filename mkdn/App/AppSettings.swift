import AppKit
import SwiftUI

private let themeModeKey = "themeMode"

private let hasShownDefaultHandlerHintKey = "hasShownDefaultHandlerHint"

/// App-wide settings shared across all windows.
///
/// Manages theme preferences and application-level state that is
/// independent of any specific document window.
@MainActor
@Observable
public final class AppSettings {
    // MARK: - Theme

    /// User's theme preference: auto (follows system), or a pinned variant.
    /// Persisted to UserDefaults under the `"themeMode"` key.
    public var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: themeModeKey)
        }
    }

    /// Current system color scheme, bridged from `@Environment(\.colorScheme)`.
    /// Initialized from `NSApp.effectiveAppearance` to prevent a flash of wrong
    /// theme before the SwiftUI colorScheme bridge fires. Updated by the root
    /// view whenever the OS appearance changes.
    public var systemColorScheme: ColorScheme

    /// Resolved color theme based on the user's mode preference and system appearance.
    /// All views read this to obtain colors and syntax highlighting.
    public var theme: AppTheme {
        themeMode.resolved(for: systemColorScheme)
    }

    // MARK: - Default Handler Hint

    /// Whether the first-launch default handler hint has been shown.
    /// Persisted to UserDefaults so the hint never reappears.
    public var hasShownDefaultHandlerHint: Bool {
        didSet {
            UserDefaults.standard.set(hasShownDefaultHandlerHint, forKey: hasShownDefaultHandlerHintKey)
        }
    }

    public init() {
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        systemColorScheme = isDark ? .dark : .light

        if let raw = UserDefaults.standard.string(forKey: themeModeKey),
           let mode = ThemeMode(rawValue: raw)
        {
            themeMode = mode
        } else {
            themeMode = .auto
        }

        hasShownDefaultHandlerHint = UserDefaults.standard.bool(forKey: hasShownDefaultHandlerHintKey)
    }

    // MARK: - Methods

    /// Cycle to the next theme mode (Auto -> Dark -> Light -> Auto).
    public func cycleTheme() {
        let allModes = ThemeMode.allCases
        guard let currentIndex = allModes.firstIndex(of: themeMode) else { return }
        let nextIndex = (currentIndex + 1) % allModes.count
        themeMode = allModes[nextIndex]
    }
}
