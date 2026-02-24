import CoreGraphics
import Testing
@testable import mkdnLib

// MARK: - Test Colors

private let red = PixelColor(red: 255, green: 0, blue: 0)
private let green = PixelColor(red: 0, green: 255, blue: 0)
private let blue = PixelColor(red: 0, green: 0, blue: 255)
private let white = PixelColor(red: 255, green: 255, blue: 255)
private let black = PixelColor(red: 0, green: 0, blue: 0)

// MARK: - PixelColor Tests

@Suite("PixelColor")
struct PixelColorTests {
    @Test("Distance between identical colors is zero")
    func identicalDistance() {
        #expect(red.distance(to: red) == 0)
    }

    @Test("Distance between black and white is 255")
    func blackWhiteDistance() {
        #expect(black.distance(to: white) == 255)
    }

    @Test("Distance is symmetric")
    func symmetricDistance() {
        let colorA = PixelColor(red: 100, green: 50, blue: 200)
        let colorB = PixelColor(red: 150, green: 100, blue: 180)
        #expect(colorA.distance(to: colorB) == colorB.distance(to: colorA))
    }

    @Test("Distance uses max channel difference (Chebyshev)")
    func chebyshevDistance() {
        let colorA = PixelColor(red: 100, green: 100, blue: 100)
        let colorB = PixelColor(red: 110, green: 130, blue: 105)
        #expect(colorA.distance(to: colorB) == 30)
    }

    @Test("From floating-point components clamps and rounds")
    func fromFloatingPoint() {
        let color = PixelColor.from(red: 1.0, green: 0.5, blue: 0.0)
        #expect(color.red == 255)
        #expect(color.green == 128)
        #expect(color.blue == 0)
        #expect(color.alpha == 255)
    }

    @Test("From floating-point clamps out-of-range values")
    func fromFloatingPointClamped() {
        let color = PixelColor.from(red: 1.5, green: -0.1, blue: 0.5)
        #expect(color.red == 255)
        #expect(color.green == 0)
        #expect(color.blue == 128)
    }

    @Test("From RGBColor produces correct PixelColor")
    func fromRGBColor() {
        let rgb = RGBColor(red: 0.0, green: 0.5, blue: 1.0)
        let color = PixelColor.from(rgbColor: rgb)
        #expect(color.red == 0)
        #expect(color.green == 128)
        #expect(color.blue == 255)
    }
}

// MARK: - ColorExtractor Tests

@Suite("ColorExtractor")
struct ColorExtractorTests {
    @Test("Exact match with zero tolerance")
    func exactMatch() {
        #expect(ColorExtractor.matches(red, expected: red, tolerance: 0))
    }

    @Test("No match with zero tolerance when different")
    func noExactMatch() {
        let almostRed = PixelColor(red: 254, green: 0, blue: 0)
        #expect(!ColorExtractor.matches(almostRed, expected: red, tolerance: 0))
    }

    @Test("Match within tolerance")
    func matchWithinTolerance() {
        let almostRed = PixelColor(red: 250, green: 3, blue: 2)
        #expect(ColorExtractor.matches(almostRed, expected: red, tolerance: 5))
    }

    @Test("No match outside tolerance")
    func noMatchOutsideTolerance() {
        let farFromRed = PixelColor(red: 240, green: 10, blue: 10)
        #expect(!ColorExtractor.matches(farFromRed, expected: red, tolerance: 5))
    }
}

// MARK: - ImageAnalyzer Tests

@Suite("ImageAnalyzer")
struct ImageAnalyzerTests {
    @Test("Sample color from solid image at 1x scale")
    func solidImageSample1x() throws {
        let image = try #require(SyntheticImage.solidColor(width: 100, height: 100, color: red))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        #expect(analyzer.sampleColor(at: CGPoint(x: 50, y: 50)) == red)
    }

    @Test("Sample color from solid image at 2x scale")
    func solidImageSample2x() throws {
        let image = try #require(SyntheticImage.solidColor(width: 200, height: 200, color: blue))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
        #expect(analyzer.sampleColor(at: CGPoint(x: 50, y: 50)) == blue)
    }

    @Test("Sample color at boundary of two-color image")
    func twoColorBoundary() throws {
        let image = try #require(SyntheticImage.twoColorHorizontal(
            width: 200,
            height: 100,
            leftColor: red,
            rightColor: blue,
            splitAtPixel: 100
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
        #expect(analyzer.sampleColor(at: CGPoint(x: 10, y: 25)) == red)
        #expect(analyzer.sampleColor(at: CGPoint(x: 80, y: 25)) == blue)
    }

    @Test("Average color of uniform region equals the region color")
    func averageColorUniform() throws {
        let image = try #require(SyntheticImage.solidColor(width: 100, height: 100, color: green))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        let avg = analyzer.averageColor(in: CGRect(x: 10, y: 10, width: 20, height: 20))
        #expect(avg == green)
    }

    @Test("Average color across two equal halves is midpoint")
    func averageColorMixed() throws {
        let image = try #require(SyntheticImage.twoColorHorizontal(
            width: 100,
            height: 100,
            leftColor: black,
            rightColor: white,
            splitAtPixel: 50
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        let avg = analyzer.averageColor(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        let midGray = 127
        #expect(abs(Int(avg.red) - midGray) <= 1)
        #expect(abs(Int(avg.green) - midGray) <= 1)
        #expect(abs(Int(avg.blue) - midGray) <= 1)
    }

    @Test("matchesColor returns true for exact match")
    func matchesColorExact() throws {
        let image = try #require(SyntheticImage.solidColor(width: 100, height: 100, color: red))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        #expect(analyzer.matchesColor(red, at: CGPoint(x: 50, y: 50), tolerance: 0))
    }

    @Test("matchesColor returns false for wrong color")
    func matchesColorWrong() throws {
        let image = try #require(SyntheticImage.solidColor(width: 100, height: 100, color: red))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        #expect(!analyzer.matchesColor(blue, at: CGPoint(x: 50, y: 50), tolerance: 0))
    }

    @Test("Point dimensions account for scale factor")
    func pointDimensions() throws {
        let image = try #require(SyntheticImage.solidColor(width: 200, height: 150, color: white))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
        #expect(analyzer.pointWidth == 100)
        #expect(analyzer.pointHeight == 75)
    }

    @Test("findColorBoundary locates horizontal boundary")
    func horizontalBoundary() throws {
        let image = try #require(SyntheticImage.twoColorHorizontal(
            width: 200,
            height: 100,
            leftColor: red,
            rightColor: blue,
            splitAtPixel: 100
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
        let boundary = try #require(analyzer.findColorBoundary(
            from: CGPoint(x: 0, y: 25),
            direction: .right,
            sourceColor: red,
            tolerance: 0
        ))
        #expect(boundary.x == 50.0)
    }

    @Test("findColorBoundary locates vertical boundary")
    func verticalBoundary() throws {
        let image = try #require(SyntheticImage.twoColorVertical(
            width: 100,
            height: 200,
            topColor: green,
            bottomColor: white,
            splitAtPixel: 100
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
        let boundary = try #require(analyzer.findColorBoundary(
            from: CGPoint(x: 25, y: 0),
            direction: .down,
            sourceColor: green,
            tolerance: 0
        ))
        #expect(boundary.y == 50.0)
    }

    @Test("findColorBoundary returns nil when no boundary exists")
    func noBoundary() throws {
        let image = try #require(SyntheticImage.solidColor(width: 100, height: 100, color: red))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        let boundary = analyzer.findColorBoundary(
            from: CGPoint(x: 0, y: 50),
            direction: .right,
            sourceColor: red,
            tolerance: 0
        )
        #expect(boundary == nil)
    }

    @Test("contentBounds finds centered box")
    func contentBoundsBox() throws {
        let image = try #require(SyntheticImage.centeredBox(
            width: 200,
            height: 200,
            background: white,
            boxColor: black,
            boxRect: CGRect(x: 40, y: 60, width: 120, height: 80)
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
        let bounds = analyzer.contentBounds(background: white, tolerance: 0)
        #expect(abs(bounds.origin.x - 20) <= 0.5)
        #expect(abs(bounds.origin.y - 30) <= 0.5)
        #expect(abs(bounds.width - 60) <= 0.5)
        #expect(abs(bounds.height - 40) <= 0.5)
    }

    @Test("contentBounds returns zero for uniform image")
    func contentBoundsUniform() throws {
        let image = try #require(SyntheticImage.solidColor(width: 100, height: 100, color: white))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        #expect(analyzer.contentBounds(background: white, tolerance: 0) == .zero)
    }

    @Test("dominantColor returns the most frequent color")
    func dominantColorTest() throws {
        let image = try #require(SyntheticImage.twoColorHorizontal(
            width: 100,
            height: 100,
            leftColor: red,
            rightColor: blue,
            splitAtPixel: 80
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        let dominant = analyzer.dominantColor(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(dominant == red)
    }

    @Test("findRegion locates a colored rectangle")
    func findRegionTest() throws {
        let image = try #require(SyntheticImage.centeredBox(
            width: 100,
            height: 100,
            background: white,
            boxColor: red,
            boxRect: CGRect(x: 20, y: 30, width: 40, height: 20)
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        let region = try #require(analyzer.findRegion(matching: red, tolerance: 0))
        #expect(abs(region.origin.x - 20) <= 1)
        #expect(abs(region.origin.y - 30) <= 1)
        #expect(abs(region.width - 40) <= 1)
        #expect(abs(region.height - 20) <= 1)
    }

    @Test("findRegion returns nil when color is absent")
    func findRegionAbsent() throws {
        let image = try #require(SyntheticImage.solidColor(width: 100, height: 100, color: white))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        #expect(analyzer.findRegion(matching: red, tolerance: 0) == nil)
    }
}
