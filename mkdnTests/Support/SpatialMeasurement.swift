import CoreGraphics

// MARK: - ScanAxis

/// Axis along which to scan for distance measurement.
enum ScanAxis: Sendable {
    case horizontal
    case vertical
}

// MARK: - SpatialMeasurement

/// Distance and edge measurement utilities for captured images.
///
/// All methods accept and return values in the **point coordinate system**
/// (1pt = `scaleFactor` pixels). Measurements are accurate to within
/// 1pt at 2x Retina scale factor.
enum SpatialMeasurement {
    /// Measures the distance from `start` in `direction` until a pixel
    /// matching `targetColor` (within `tolerance`) is found.
    ///
    /// Returns the distance in points, or `nil` if the target color is
    /// not found before the image edge.
    static func measureEdge(
        in analyzer: ImageAnalyzer,
        from start: CGPoint,
        direction: Direction,
        targetColor: PixelColor,
        tolerance: Int = 5
    ) -> CGFloat? {
        let scale = analyzer.scaleFactor
        var px = Int((start.x * scale).rounded())
        var py = Int((start.y * scale).rounded())
        let step = stepVector(direction)
        let startPx = px
        let startPy = py

        while px >= 0, px < analyzer.image.width,
              py >= 0, py < analyzer.image.height
        {
            let color = analyzer.sampleColor(
                at: CGPoint(
                    x: CGFloat(px) / scale,
                    y: CGFloat(py) / scale
                )
            )

            if ColorExtractor.matches(color, expected: targetColor, tolerance: tolerance) {
                let dx = abs(px - startPx)
                let dy = abs(py - startPy)
                return CGFloat(max(dx, dy)) / scale
            }

            px += step.dx
            py += step.dy
        }

        return nil
    }

    /// Measures the distance between two color boundaries along a scan line.
    ///
    /// Scans along `axis` at coordinate `at` (the perpendicular coordinate
    /// in points). Finds the first boundary of `colorA` and the first
    /// boundary of `colorB`, then returns the distance between them in
    /// points.
    ///
    /// - Parameters:
    ///   - colorA: The first color to locate.
    ///   - colorB: The second color to locate.
    ///   - axis: The axis to scan along.
    ///   - at: The perpendicular coordinate (points) for the scan line.
    ///   - tolerance: Color matching tolerance per channel.
    /// - Returns: Distance in points, or `nil` if either color is not found.
    static func measureDistance(
        in analyzer: ImageAnalyzer,
        between colorA: PixelColor,
        and colorB: PixelColor,
        along axis: ScanAxis,
        at: CGFloat,
        tolerance: Int = 5
    ) -> CGFloat? {
        let scale = analyzer.scaleFactor
        let posA = findFirstOccurrence(
            in: analyzer,
            color: colorA,
            axis: axis,
            at: at,
            tolerance: tolerance
        )
        let posB = findFirstOccurrence(
            in: analyzer,
            color: colorB,
            axis: axis,
            at: at,
            tolerance: tolerance
        )

        guard let foundA = posA, let foundB = posB else {
            return nil
        }

        return abs(CGFloat(foundB - foundA)) / scale
    }

    /// Measures the gap between the trailing edge of one color region and
    /// the leading edge of the next color region along a scan line.
    ///
    /// This is the primary measurement for block spacing: scan vertically,
    /// find where the first block's color ends, then find where the next
    /// block's color begins, and return the distance in points.
    static func measureGap(
        in analyzer: ImageAnalyzer,
        from fromColor: PixelColor,
        to toColor: PixelColor,
        along axis: ScanAxis,
        at: CGFloat,
        tolerance: Int = 5
    ) -> CGFloat? {
        let scale = analyzer.scaleFactor
        let scanLimit = axis == .vertical ? analyzer.image.height : analyzer.image.width
        let fixedPx = Int((at * scale).rounded())

        var foundFromEnd: Int?
        var inFromRegion = false

        for scanPx in 0 ..< scanLimit {
            let (px, py) = axis == .vertical
                ? (fixedPx, scanPx)
                : (scanPx, fixedPx)
            let color = samplePixelDirect(in: analyzer, x: px, y: py)

            if ColorExtractor.matches(color, expected: fromColor, tolerance: tolerance) {
                inFromRegion = true
            } else if inFromRegion {
                foundFromEnd = scanPx
                break
            }
        }

        guard let fromEnd = foundFromEnd else { return nil }

        for scanPx in fromEnd ..< scanLimit {
            let (px, py) = axis == .vertical
                ? (fixedPx, scanPx)
                : (scanPx, fixedPx)
            let color = samplePixelDirect(in: analyzer, x: px, y: py)

            if ColorExtractor.matches(color, expected: toColor, tolerance: tolerance) {
                return CGFloat(scanPx - fromEnd) / scale
            }
        }

        return nil
    }
}

// MARK: - Private Helpers

private extension SpatialMeasurement {
    static func stepVector(_ direction: Direction) -> (dx: Int, dy: Int) {
        switch direction {
        case .up: (dx: 0, dy: -1)
        case .down: (dx: 0, dy: 1)
        case .left: (dx: -1, dy: 0)
        case .right: (dx: 1, dy: 0)
        }
    }

    static func findFirstOccurrence(
        in analyzer: ImageAnalyzer,
        color: PixelColor,
        axis: ScanAxis,
        at: CGFloat,
        tolerance: Int
    ) -> Int? {
        let scale = analyzer.scaleFactor
        let fixedPx = Int((at * scale).rounded())
        let scanLimit = axis == .vertical
            ? analyzer.image.height
            : analyzer.image.width

        for scanPx in 0 ..< scanLimit {
            let (px, py) = axis == .vertical
                ? (fixedPx, scanPx)
                : (scanPx, fixedPx)
            let pointX = CGFloat(px) / scale
            let pointY = CGFloat(py) / scale
            let sampled = analyzer.sampleColor(at: CGPoint(x: pointX, y: pointY))

            if ColorExtractor.matches(sampled, expected: color, tolerance: tolerance) {
                return scanPx
            }
        }
        return nil
    }

    static func samplePixelDirect(in analyzer: ImageAnalyzer, x: Int, y: Int) -> PixelColor {
        let scale = analyzer.scaleFactor
        return analyzer.sampleColor(
            at: CGPoint(x: CGFloat(x) / scale, y: CGFloat(y) / scale)
        )
    }
}
