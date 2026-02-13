import AppKit
import SwiftUI

/// Converts SwiftUI types to AppKit platform equivalents for NSTextView rendering.
enum PlatformTypeConverter {
    // MARK: - Color Conversion

    static func nsColor(from color: Color) -> NSColor {
        NSColor(color)
    }

    // MARK: - Font Factory

    static func headingFont(level: Int, scaleFactor: CGFloat = 1.0) -> NSFont {
        let baseSize: CGFloat = switch level {
        case 1: 28
        case 2: 24
        case 3: 20
        case 4: 18
        case 5: 16
        default: 14
        }
        let weight: NSFont.Weight = level <= 2 ? .bold : level <= 4 ? .semibold : .medium
        return .systemFont(ofSize: baseSize * scaleFactor, weight: weight)
    }

    static func bodyFont(scaleFactor: CGFloat = 1.0) -> NSFont {
        let base = NSFont.preferredFont(forTextStyle: .body)
        return .systemFont(ofSize: base.pointSize * scaleFactor)
    }

    static func monospacedFont(scaleFactor: CGFloat = 1.0) -> NSFont {
        .monospacedSystemFont(ofSize: NSFont.systemFontSize * scaleFactor, weight: .regular)
    }

    static func captionMonospacedFont(scaleFactor: CGFloat = 1.0) -> NSFont {
        .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize * scaleFactor, weight: .regular)
    }

    // MARK: - Paragraph Style

    static func paragraphStyle(
        lineSpacing: CGFloat = 0,
        paragraphSpacing: CGFloat = 0,
        alignment: NSTextAlignment = .left
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        style.alignment = alignment
        return style
    }
}
