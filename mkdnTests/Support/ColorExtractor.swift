import CoreGraphics
@testable import mkdnLib

// MARK: - PixelColor

/// An RGBA color sampled from a captured image.
///
/// Values are raw byte components (0--255). All comparison and conversion
/// methods are intentionally simple: the test infrastructure needs exact
/// pixel-level control, not color-space sophistication.
struct PixelColor: Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Maximum per-channel distance (Chebyshev distance).
    ///
    /// Returns the largest absolute difference across R, G, B channels.
    /// Alpha is excluded because anti-aliased text produces blended alpha
    /// that should not trigger spatial boundary detection.
    func distance(to other: Self) -> Int {
        let dr = abs(Int(red) - Int(other.red))
        let dg = abs(Int(green) - Int(other.green))
        let db = abs(Int(blue) - Int(other.blue))
        return max(dr, dg, db)
    }

    /// Creates a `PixelColor` from floating-point RGB components in 0.0--1.0.
    ///
    /// Maps to the same representation as SwiftUI's `Color(red:green:blue:)`
    /// constructor values. Components are clamped to 0.0--1.0 before conversion.
    static func from(
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1.0
    ) -> Self {
        Self(
            red: UInt8(clamping: Int((min(max(red, 0), 1) * 255).rounded())),
            green: UInt8(clamping: Int((min(max(green, 0), 1) * 255).rounded())),
            blue: UInt8(clamping: Int((min(max(blue, 0), 1) * 255).rounded())),
            alpha: UInt8(clamping: Int((min(max(alpha, 0), 1) * 255).rounded()))
        )
    }

    /// Creates a `PixelColor` from the harness protocol's `RGBColor` type.
    static func from(rgbColor: RGBColor) -> Self {
        from(red: rgbColor.red, green: rgbColor.green, blue: rgbColor.blue)
    }
}

// MARK: - PixelColor + Debug

extension PixelColor: CustomStringConvertible {
    var description: String {
        "PixelColor(r:\(red), g:\(green), b:\(blue), a:\(alpha))"
    }
}

// MARK: - ColorExtractor

/// Utilities for comparing pixel colors with configurable tolerance.
enum ColorExtractor {
    /// Returns `true` when the Chebyshev distance between colors is at
    /// or below `tolerance`.
    ///
    /// A tolerance of 0 requires exact match. Typical values for
    /// anti-aliasing compensation range from 3--10.
    static func matches(
        _ actual: PixelColor,
        expected: PixelColor,
        tolerance: Int
    ) -> Bool {
        actual.distance(to: expected) <= tolerance
    }
}
