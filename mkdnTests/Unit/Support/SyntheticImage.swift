import CoreGraphics

/// Creates CGImages with known geometry and colors for testing.
///
/// All images use the `premultipliedLast` RGBA pixel format, matching
/// the format expected by `ImageAnalyzer`. CGContext draws with
/// a top-left origin, consistent with `CGWindowListCreateImage` output.
enum SyntheticImage {
    static func solidColor(
        width: Int,
        height: Int,
        color: PixelColor
    ) -> CGImage? {
        guard let context = createContext(width: width, height: height) else { return nil }
        context.setFillColor(cgColor(from: color))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    static func twoColorHorizontal(
        width: Int,
        height: Int,
        leftColor: PixelColor,
        rightColor: PixelColor,
        splitAtPixel: Int
    ) -> CGImage? {
        guard let context = createContext(width: width, height: height) else { return nil }
        context.setFillColor(cgColor(from: leftColor))
        context.fill(CGRect(x: 0, y: 0, width: splitAtPixel, height: height))
        context.setFillColor(cgColor(from: rightColor))
        context.fill(CGRect(x: splitAtPixel, y: 0, width: width - splitAtPixel, height: height))
        return context.makeImage()
    }

    static func twoColorVertical(
        width: Int,
        height: Int,
        topColor: PixelColor,
        bottomColor: PixelColor,
        splitAtPixel: Int
    ) -> CGImage? {
        guard let context = createContext(width: width, height: height) else { return nil }
        context.setFillColor(cgColor(from: topColor))
        context.fill(CGRect(x: 0, y: 0, width: width, height: splitAtPixel))
        context.setFillColor(cgColor(from: bottomColor))
        context.fill(CGRect(x: 0, y: splitAtPixel, width: width, height: height - splitAtPixel))
        return context.makeImage()
    }

    static func centeredBox(
        width: Int,
        height: Int,
        background: PixelColor,
        boxColor: PixelColor,
        boxRect: CGRect
    ) -> CGImage? {
        guard let context = createContext(width: width, height: height) else { return nil }
        context.setFillColor(cgColor(from: background))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(cgColor(from: boxColor))
        context.fill(boxRect)
        return context.makeImage()
    }

    /// Three horizontal stripes configuration.
    struct StripeConfig {
        let topColor: PixelColor
        let middleColor: PixelColor
        let bottomColor: PixelColor
        let firstSplit: Int
        let secondSplit: Int
    }

    static func threeStripes(
        width: Int,
        height: Int,
        config: StripeConfig
    ) -> CGImage? {
        guard let context = createContext(width: width, height: height) else { return nil }
        context.setFillColor(cgColor(from: config.topColor))
        context.fill(CGRect(x: 0, y: 0, width: width, height: config.firstSplit))
        context.setFillColor(cgColor(from: config.middleColor))
        let midHeight = config.secondSplit - config.firstSplit
        context.fill(CGRect(x: 0, y: config.firstSplit, width: width, height: midHeight))
        context.setFillColor(cgColor(from: config.bottomColor))
        let botHeight = height - config.secondSplit
        context.fill(CGRect(x: 0, y: config.secondSplit, width: width, height: botHeight))
        return context.makeImage()
    }

    private static let deviceRGB = CGColorSpaceCreateDeviceRGB()

    private static func createContext(width: Int, height: Int) -> CGContext? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: deviceRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else {
            return nil
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        return context
    }

    private static func cgColor(from pixel: PixelColor) -> CGColor {
        let components: [CGFloat] = [
            CGFloat(pixel.red) / 255.0,
            CGFloat(pixel.green) / 255.0,
            CGFloat(pixel.blue) / 255.0,
            CGFloat(pixel.alpha) / 255.0,
        ]
        return CGColor(colorSpace: deviceRGB, components: components) ?? CGColor(gray: 0, alpha: 1)
    }
}
