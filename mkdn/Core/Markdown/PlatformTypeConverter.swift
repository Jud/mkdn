#if os(macOS)
    import AppKit
#else
    import UIKit
#endif
import SwiftUI

/// Converts SwiftUI types to platform equivalents for attributed string rendering.
/// Serves as the cross-platform abstraction hub: all platform-specific type references
/// in core rendering files route through typealiases and bridge methods defined here.
public enum PlatformTypeConverter {
    // MARK: - Platform Type Aliases

    #if os(macOS)
        public typealias PlatformFont = NSFont
        public typealias PlatformColor = NSColor
        public typealias PlatformImage = NSImage
    #else
        public typealias PlatformFont = UIFont
        public typealias PlatformColor = UIColor
        public typealias PlatformImage = UIImage
    #endif

    // MARK: - Font Trait Bridge

    public struct FontTrait: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let bold = Self(rawValue: 1 << 0)
        public static let italic = Self(rawValue: 1 << 1)
    }

    public static func convertFont(
        _ font: PlatformFont,
        toHaveTrait trait: FontTrait
    ) -> PlatformFont {
        #if os(macOS)
            var nsMask: NSFontTraitMask = []
            if trait.contains(.bold) { nsMask.insert(.boldFontMask) }
            if trait.contains(.italic) { nsMask.insert(.italicFontMask) }
            return NSFontManager.shared.convert(font, toHaveTrait: nsMask)
        #else
            var symbolicTraits = font.fontDescriptor.symbolicTraits
            if trait.contains(.bold) { symbolicTraits.insert(.traitBold) }
            if trait.contains(.italic) { symbolicTraits.insert(.traitItalic) }
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(symbolicTraits) else {
                return font
            }
            return UIFont(descriptor: descriptor, size: 0)
        #endif
    }

    // MARK: - Color Conversion

    public static func color(from color: Color) -> PlatformColor {
        PlatformColor(color)
    }

    // MARK: - Font Factory

    public static func headingFont(level: Int, scaleFactor: CGFloat = 1.0) -> PlatformFont {
        let baseSize: CGFloat = switch level {
        case 1: 28
        case 2: 24
        case 3: 20
        case 4: 18
        case 5: 16
        default: 14
        }
        let weight: PlatformFont.Weight = level <= 2 ? .bold : level <= 4 ? .semibold : .medium
        return .systemFont(ofSize: baseSize * scaleFactor, weight: weight)
    }

    public static func bodyFont(scaleFactor: CGFloat = 1.0) -> PlatformFont {
        let base = PlatformFont.preferredFont(forTextStyle: .body)
        return .systemFont(ofSize: base.pointSize * scaleFactor)
    }

    public static func monospacedFont(scaleFactor: CGFloat = 1.0) -> PlatformFont {
        .monospacedSystemFont(ofSize: PlatformFont.systemFontSize * scaleFactor, weight: .regular)
    }

    public static func captionMonospacedFont(scaleFactor: CGFloat = 1.0) -> PlatformFont {
        .monospacedSystemFont(ofSize: PlatformFont.smallSystemFontSize * scaleFactor, weight: .regular)
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
