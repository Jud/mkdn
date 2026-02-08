import AppKit
import SwiftUI

/// Converts SwiftUI types to AppKit platform equivalents for NSTextView rendering.
enum PlatformTypeConverter {
    // MARK: - Color Conversion

    static func nsColor(from color: Color) -> NSColor {
        NSColor(color)
    }

    // MARK: - Font Factory

    static func headingFont(level: Int) -> NSFont {
        switch level {
        case 1: .systemFont(ofSize: 28, weight: .bold)
        case 2: .systemFont(ofSize: 24, weight: .bold)
        case 3: .systemFont(ofSize: 20, weight: .semibold)
        case 4: .systemFont(ofSize: 18, weight: .semibold)
        case 5: .systemFont(ofSize: 16, weight: .medium)
        default: .systemFont(ofSize: 14, weight: .medium)
        }
    }

    static func bodyFont() -> NSFont {
        .preferredFont(forTextStyle: .body)
    }

    static func monospacedFont() -> NSFont {
        .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    static func captionMonospacedFont() -> NSFont {
        .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
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
