import Foundation

/// Response sent from the app back to the test runner.
public struct HarnessResponse: Codable, Sendable {
    /// `"ok"` on success, `"error"` on failure.
    public let status: String

    /// Human-readable message. Present on errors; optional on success.
    public let message: String?

    /// Structured response payload, varies by command.
    public let data: ResponseData?

    public init(status: String, message: String? = nil, data: ResponseData? = nil) {
        self.status = status
        self.message = message
        self.data = data
    }

    /// Convenience: success response with no payload.
    public static func ok(message: String? = nil) -> Self {
        Self(status: "ok", message: message)
    }

    /// Convenience: success response with data.
    public static func ok(data: ResponseData, message: String? = nil) -> Self {
        Self(status: "ok", message: message, data: data)
    }

    /// Convenience: error response.
    public static func error(_ message: String) -> Self {
        Self(status: "error", message: message)
    }
}

// MARK: - Response Data

/// Typed response payloads for different command results.
public enum ResponseData: Codable, Sendable {
    case capture(CaptureResult)
    case frameCapture(FrameCaptureResult)
    case windowInfo(WindowInfoResult)
    case themeColors(ThemeColorsResult)
    case pong
}

// MARK: - Result Types

/// Result of a single-frame window or region capture.
public struct CaptureResult: Codable, Sendable, Equatable {
    /// File path where the PNG was written.
    public let imagePath: String

    /// Image width in pixels.
    public let width: Int

    /// Image height in pixels.
    public let height: Int

    /// Display scale factor (e.g. 2.0 for Retina).
    public let scaleFactor: Double

    /// Capture timestamp.
    public let timestamp: Date

    /// Active theme at capture time.
    public let theme: String

    /// Active view mode at capture time.
    public let viewMode: String

    public init(
        imagePath: String,
        width: Int,
        height: Int,
        scaleFactor: Double,
        timestamp: Date,
        theme: String,
        viewMode: String
    ) {
        self.imagePath = imagePath
        self.width = width
        self.height = height
        self.scaleFactor = scaleFactor
        self.timestamp = timestamp
        self.theme = theme
        self.viewMode = viewMode
    }
}

/// Result of a multi-frame animation capture session.
public struct FrameCaptureResult: Codable, Sendable, Equatable {
    /// Directory containing the numbered frame PNGs.
    public let frameDir: String

    /// Total frames captured.
    public let frameCount: Int

    /// Requested frames per second.
    public let fps: Int

    /// Actual capture duration in seconds.
    public let duration: Double

    /// Ordered list of frame file paths.
    public let framePaths: [String]

    public init(
        frameDir: String,
        frameCount: Int,
        fps: Int,
        duration: Double,
        framePaths: [String]
    ) {
        self.frameDir = frameDir
        self.frameCount = frameCount
        self.fps = fps
        self.duration = duration
        self.framePaths = framePaths
    }
}

/// Current window geometry and display information.
public struct WindowInfoResult: Codable, Sendable, Equatable {
    /// Window width in points.
    public let width: Double

    /// Window height in points.
    public let height: Double

    /// Window X position on screen.
    public let x: Double

    /// Window Y position on screen.
    public let y: Double

    /// Display scale factor (e.g. 2.0 for Retina).
    public let scaleFactor: Double

    /// Active theme name.
    public let theme: String

    /// Active view mode.
    public let viewMode: String

    /// Path of the currently loaded file, if any.
    public let currentFilePath: String?

    public init(
        width: Double,
        height: Double,
        x: Double,
        y: Double,
        scaleFactor: Double,
        theme: String,
        viewMode: String,
        currentFilePath: String?
    ) {
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.scaleFactor = scaleFactor
        self.theme = theme
        self.viewMode = viewMode
        self.currentFilePath = currentFilePath
    }
}

/// RGB color values for the active theme.
///
/// Each color is represented as an `RGBColor` with red, green, blue
/// components in the 0.0--1.0 range.
public struct ThemeColorsResult: Codable, Sendable, Equatable {
    public let themeName: String
    public let background: RGBColor
    public let backgroundSecondary: RGBColor
    public let foreground: RGBColor
    public let foregroundSecondary: RGBColor
    public let accent: RGBColor
    public let headingColor: RGBColor
    public let codeBackground: RGBColor
    public let codeForeground: RGBColor
    public let linkColor: RGBColor

    public init(
        themeName: String,
        background: RGBColor,
        backgroundSecondary: RGBColor,
        foreground: RGBColor,
        foregroundSecondary: RGBColor,
        accent: RGBColor,
        headingColor: RGBColor,
        codeBackground: RGBColor,
        codeForeground: RGBColor,
        linkColor: RGBColor
    ) {
        self.themeName = themeName
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.foreground = foreground
        self.foregroundSecondary = foregroundSecondary
        self.accent = accent
        self.headingColor = headingColor
        self.codeBackground = codeBackground
        self.codeForeground = codeForeground
        self.linkColor = linkColor
    }
}

/// A color represented as red, green, blue components in the 0.0--1.0 range.
public struct RGBColor: Codable, Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}
