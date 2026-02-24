import CoreGraphics
import Foundation

// MARK: - Direction

/// Cardinal direction for pixel-walking operations.
enum Direction: Sendable {
    case up
    case down
    case left
    case right
}

// MARK: - ImageAnalyzer

/// Pixel-level analysis of captured `CGImage` data.
///
/// All point parameters use the **point coordinate system** (origin at
/// top-left, matching `CGWindowListCreateImage` output). The analyzer
/// converts to pixel coordinates internally using `scaleFactor`.
///
/// Thread-safe: the analyzer copies pixel data at init time and holds
/// no mutable state.
struct ImageAnalyzer: Sendable {
    let image: CGImage
    let scaleFactor: CGFloat

    private let pixelData: Data
    private let bytesPerRow: Int
    private let bytesPerPixel: Int
    private let pixelWidth: Int
    private let pixelHeight: Int

    /// Width of the image in points.
    var pointWidth: CGFloat {
        CGFloat(pixelWidth) / scaleFactor
    }

    /// Height of the image in points.
    var pointHeight: CGFloat {
        CGFloat(pixelHeight) / scaleFactor
    }

    init(image: CGImage, scaleFactor: CGFloat = 2.0) {
        self.image = image
        self.scaleFactor = scaleFactor
        pixelWidth = image.width
        pixelHeight = image.height
        bytesPerRow = image.bytesPerRow
        bytesPerPixel = image.bitsPerPixel / 8

        if let provider = image.dataProvider,
           let cfData = provider.data
        {
            pixelData = cfData as Data
        } else {
            pixelData = Data()
        }
    }

    // MARK: - Color Sampling

    /// Samples the color at a point (in the point coordinate system).
    func sampleColor(at point: CGPoint) -> PixelColor {
        let px = Int((point.x * scaleFactor).rounded())
        let py = Int((point.y * scaleFactor).rounded())
        return samplePixel(x: px, y: py)
    }

    /// Average color across all pixels in a rect (point coordinates).
    func averageColor(in rect: CGRect) -> PixelColor {
        let minX = Int((rect.minX * scaleFactor).rounded())
        let minY = Int((rect.minY * scaleFactor).rounded())
        let maxX = Int((rect.maxX * scaleFactor).rounded())
        let maxY = Int((rect.maxY * scaleFactor).rounded())

        let clampedMinX = max(0, minX)
        let clampedMinY = max(0, minY)
        let clampedMaxX = min(pixelWidth - 1, maxX)
        let clampedMaxY = min(pixelHeight - 1, maxY)

        var totalR = 0
        var totalG = 0
        var totalB = 0
        var totalA = 0
        var count = 0

        for py in clampedMinY ... clampedMaxY {
            for px in clampedMinX ... clampedMaxX {
                let color = samplePixel(x: px, y: py)
                totalR += Int(color.red)
                totalG += Int(color.green)
                totalB += Int(color.blue)
                totalA += Int(color.alpha)
                count += 1
            }
        }

        guard count > 0 else {
            return PixelColor(red: 0, green: 0, blue: 0, alpha: 0)
        }

        return PixelColor(
            red: UInt8(totalR / count),
            green: UInt8(totalG / count),
            blue: UInt8(totalB / count),
            alpha: UInt8(totalA / count)
        )
    }

    /// Returns `true` when the color at `point` is within `tolerance` of
    /// `expected`.
    func matchesColor(
        _ expected: PixelColor,
        at point: CGPoint,
        tolerance: Int = 0
    ) -> Bool {
        let actual = sampleColor(at: point)
        return ColorExtractor.matches(actual, expected: expected, tolerance: tolerance)
    }

    // MARK: - Boundary Detection

    /// Walks pixels from `start` in `direction` until the color differs
    /// from `sourceColor` beyond `tolerance`.
    ///
    /// Returns the point (in point coordinates) of the first pixel that
    /// does **not** match `sourceColor`, or `nil` if the image edge is
    /// reached without finding a boundary.
    func findColorBoundary(
        from start: CGPoint,
        direction: Direction,
        sourceColor: PixelColor,
        tolerance: Int = 5
    ) -> CGPoint? {
        var px = Int((start.x * scaleFactor).rounded())
        var py = Int((start.y * scaleFactor).rounded())
        let step = directionStep(direction)

        while px >= 0, px < pixelWidth, py >= 0, py < pixelHeight {
            let color = samplePixel(x: px, y: py)
            if !ColorExtractor.matches(color, expected: sourceColor, tolerance: tolerance) {
                return CGPoint(
                    x: CGFloat(px) / scaleFactor,
                    y: CGFloat(py) / scaleFactor
                )
            }
            px += step.dx
            py += step.dy
        }

        return nil
    }

    /// Finds the dominant (most frequent) color in a rect (point coordinates).
    func dominantColor(in rect: CGRect) -> PixelColor {
        let minX = Int((rect.minX * scaleFactor).rounded())
        let minY = Int((rect.minY * scaleFactor).rounded())
        let maxX = Int((rect.maxX * scaleFactor).rounded())
        let maxY = Int((rect.maxY * scaleFactor).rounded())

        let clampedMinX = max(0, minX)
        let clampedMinY = max(0, minY)
        let clampedMaxX = min(pixelWidth - 1, maxX)
        let clampedMaxY = min(pixelHeight - 1, maxY)

        var histogram: [UInt64: Int] = [:]

        for py in clampedMinY ... clampedMaxY {
            for px in clampedMinX ... clampedMaxX {
                let color = samplePixel(x: px, y: py)
                let key = colorKey(color)
                histogram[key, default: 0] += 1
            }
        }

        guard let (topKey, _) = histogram.max(by: { $0.value < $1.value }) else {
            return PixelColor(red: 0, green: 0, blue: 0, alpha: 0)
        }

        return colorFromKey(topKey)
    }

    // MARK: - Region Analysis

    /// Finds the bounding rect of all content that differs from `background`.
    ///
    /// Scans inward from each edge to find the first non-background row/column.
    /// Returns the tight bounding rect in point coordinates.
    func contentBounds(background: PixelColor, tolerance: Int = 5) -> CGRect {
        let topPx = scanFromTop(background: background, tolerance: tolerance)
        let bottomPx = scanFromBottom(background: background, tolerance: tolerance)

        guard topPx <= bottomPx else {
            return .zero
        }

        let leftPx = scanFromLeft(
            background: background,
            tolerance: tolerance,
            topPx: topPx,
            bottomPx: bottomPx
        )
        let rightPx = scanFromRight(
            background: background,
            tolerance: tolerance,
            topPx: topPx,
            bottomPx: bottomPx
        )

        guard leftPx <= rightPx else {
            return .zero
        }

        return CGRect(
            x: CGFloat(leftPx) / scaleFactor,
            y: CGFloat(topPx) / scaleFactor,
            width: CGFloat(rightPx - leftPx + 1) / scaleFactor,
            height: CGFloat(bottomPx - topPx + 1) / scaleFactor
        )
    }

    /// Finds a rectangular region filled with the given color.
    ///
    /// Scans the image for the first pixel matching `color` within
    /// `tolerance`, then expands the rect in all directions while pixels
    /// continue to match.
    func findRegion(matching color: PixelColor, tolerance: Int = 5) -> CGRect? {
        guard let seed = findFirstPixel(matching: color, tolerance: tolerance) else {
            return nil
        }

        var minX = seed.x
        var maxX = seed.x
        var minY = seed.y
        var maxY = seed.y

        while minX > 0,
              ColorExtractor.matches(samplePixel(x: minX - 1, y: seed.y), expected: color, tolerance: tolerance)
        {
            minX -= 1
        }
        while maxX < pixelWidth - 1,
              ColorExtractor.matches(samplePixel(x: maxX + 1, y: seed.y), expected: color, tolerance: tolerance)
        {
            maxX += 1
        }
        while minY > 0,
              ColorExtractor.matches(samplePixel(x: seed.x, y: minY - 1), expected: color, tolerance: tolerance)
        {
            minY -= 1
        }
        while maxY < pixelHeight - 1,
              ColorExtractor.matches(samplePixel(x: seed.x, y: maxY + 1), expected: color, tolerance: tolerance)
        {
            maxY += 1
        }

        return CGRect(
            x: CGFloat(minX) / scaleFactor,
            y: CGFloat(minY) / scaleFactor,
            width: CGFloat(maxX - minX + 1) / scaleFactor,
            height: CGFloat(maxY - minY + 1) / scaleFactor
        )
    }
}

// MARK: - Private Helpers

private extension ImageAnalyzer {
    func samplePixel(x: Int, y: Int) -> PixelColor {
        guard x >= 0, x < pixelWidth, y >= 0, y < pixelHeight else {
            return PixelColor(red: 0, green: 0, blue: 0, alpha: 0)
        }

        let offset = y * bytesPerRow + x * bytesPerPixel

        guard offset + 3 < pixelData.count else {
            return PixelColor(red: 0, green: 0, blue: 0, alpha: 0)
        }

        return pixelData.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return PixelColor(red: 0, green: 0, blue: 0, alpha: 0)
            }
            let base = baseAddress.assumingMemoryBound(to: UInt8.self)
            let b0 = base[offset + 0]
            let b1 = base[offset + 1]
            let b2 = base[offset + 2]
            let b3 = base[offset + 3]
            return pixelFromBytes(b0: b0, b1: b1, b2: b2, b3: b3)
        }
    }

    /// Interprets four raw bytes as RGBA based on the image's bitmap info.
    ///
    /// Handles the common macOS pixel formats:
    /// - Default/big-endian + premultipliedLast: R G B A
    /// - Default/big-endian + premultipliedFirst: A R G B
    /// - Little-endian + premultipliedFirst: B G R A (CGWindowListCreateImage)
    /// - Little-endian + premultipliedLast: A B G R
    func pixelFromBytes(b0: UInt8, b1: UInt8, b2: UInt8, b3: UInt8) -> PixelColor {
        let byteOrder = image.bitmapInfo.intersection(.byteOrderMask)
        let alphaInfo = image.alphaInfo
        let alphaFirst = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst

        if byteOrder == .byteOrder32Little {
            if alphaFirst {
                return PixelColor(red: b2, green: b1, blue: b0, alpha: b3)
            }
            return PixelColor(red: b3, green: b2, blue: b1, alpha: b0)
        }

        if alphaFirst {
            return PixelColor(red: b1, green: b2, blue: b3, alpha: b0)
        }
        return PixelColor(red: b0, green: b1, blue: b2, alpha: b3)
    }

    func directionStep(_ direction: Direction) -> (dx: Int, dy: Int) {
        switch direction {
        case .up: (dx: 0, dy: -1)
        case .down: (dx: 0, dy: 1)
        case .left: (dx: -1, dy: 0)
        case .right: (dx: 1, dy: 0)
        }
    }

    func colorKey(_ color: PixelColor) -> UInt64 {
        UInt64(color.red) << 24
            | UInt64(color.green) << 16
            | UInt64(color.blue) << 8
            | UInt64(color.alpha)
    }

    func colorFromKey(_ key: UInt64) -> PixelColor {
        PixelColor(
            red: UInt8((key >> 24) & 0xFF),
            green: UInt8((key >> 16) & 0xFF),
            blue: UInt8((key >> 8) & 0xFF),
            alpha: UInt8(key & 0xFF)
        )
    }

    func findFirstPixel(matching color: PixelColor, tolerance: Int) -> (x: Int, y: Int)? {
        for py in 0 ..< pixelHeight {
            for px in 0 ..< pixelWidth
                where ColorExtractor.matches(samplePixel(x: px, y: py), expected: color, tolerance: tolerance)
            {
                return (px, py)
            }
        }
        return nil
    }

    func scanFromTop(background: PixelColor, tolerance: Int) -> Int {
        for py in 0 ..< pixelHeight where rowHasContent(py: py, background: background, tolerance: tolerance) {
            return py
        }
        return pixelHeight
    }

    func scanFromBottom(background: PixelColor, tolerance: Int) -> Int {
        for py in stride(from: pixelHeight - 1, through: 0, by: -1)
            where rowHasContent(py: py, background: background, tolerance: tolerance)
        {
            return py
        }
        return -1
    }

    func scanFromLeft(
        background: PixelColor,
        tolerance: Int,
        topPx: Int,
        bottomPx: Int
    ) -> Int {
        for px in 0 ..< pixelWidth
            where columnHasContent(
                px: px,
                background: background,
                tolerance: tolerance,
                topPx: topPx,
                bottomPx: bottomPx
            )
        {
            return px
        }
        return pixelWidth
    }

    func scanFromRight(
        background: PixelColor,
        tolerance: Int,
        topPx: Int,
        bottomPx: Int
    ) -> Int {
        for px in stride(from: pixelWidth - 1, through: 0, by: -1)
            where columnHasContent(
                px: px,
                background: background,
                tolerance: tolerance,
                topPx: topPx,
                bottomPx: bottomPx
            )
        {
            return px
        }
        return -1
    }

    func rowHasContent(py: Int, background: PixelColor, tolerance: Int) -> Bool {
        (0 ..< pixelWidth).contains { px in
            !ColorExtractor.matches(samplePixel(x: px, y: py), expected: background, tolerance: tolerance)
        }
    }

    func columnHasContent(
        px: Int,
        background: PixelColor,
        tolerance: Int,
        topPx: Int,
        bottomPx: Int
    ) -> Bool {
        (topPx ... bottomPx).contains { py in
            !ColorExtractor.matches(samplePixel(x: px, y: py), expected: background, tolerance: tolerance)
        }
    }
}
