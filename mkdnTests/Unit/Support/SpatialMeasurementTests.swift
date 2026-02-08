import CoreGraphics
import Testing

// MARK: - Test Colors

private let red = PixelColor(red: 255, green: 0, blue: 0)
private let white = PixelColor(red: 255, green: 255, blue: 255)
private let blue = PixelColor(red: 0, green: 0, blue: 255)
private let black = PixelColor(red: 0, green: 0, blue: 0)

// MARK: - SpatialMeasurement Tests

@Suite("SpatialMeasurement")
struct SpatialMeasurementTests {
    @Test("measureEdge finds distance to target color at 2x scale")
    func measureEdgeRetina() throws {
        let image = try #require(SyntheticImage.twoColorHorizontal(
            width: 200,
            height: 100,
            leftColor: white,
            rightColor: red,
            splitAtPixel: 64
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
        let distance = try #require(SpatialMeasurement.measureEdge(
            in: analyzer,
            from: CGPoint(x: 0, y: 25),
            direction: .right,
            targetColor: red,
            tolerance: 0
        ))
        #expect(abs(distance - 32.0) <= 1.0)
    }

    @Test("measureEdge returns nil when target not found")
    func measureEdgeNotFound() throws {
        let image = try #require(SyntheticImage.solidColor(width: 100, height: 100, color: white))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        let distance = SpatialMeasurement.measureEdge(
            in: analyzer,
            from: CGPoint(x: 0, y: 50),
            direction: .right,
            targetColor: red,
            tolerance: 0
        )
        #expect(distance == nil)
    }

    @Test("measureDistance between two colors along vertical axis")
    func measureDistanceVertical() throws {
        let stripeConfig = SyntheticImage.StripeConfig(
            topColor: red,
            middleColor: white,
            bottomColor: blue,
            firstSplit: 100,
            secondSplit: 200
        )
        let image = try #require(SyntheticImage.threeStripes(width: 100, height: 300, config: stripeConfig))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        let distance = try #require(SpatialMeasurement.measureDistance(
            in: analyzer,
            between: red,
            and: blue,
            along: .vertical,
            at: 50,
            tolerance: 0
        ))
        #expect(abs(distance - 200.0) <= 1.0)
    }

    @Test("measureGap between two color regions separated by background")
    func measureGapVertical() throws {
        let stripeConfig = SyntheticImage.StripeConfig(
            topColor: red,
            middleColor: white,
            bottomColor: blue,
            firstSplit: 80,
            secondSplit: 200
        )
        let image = try #require(SyntheticImage.threeStripes(width: 100, height: 300, config: stripeConfig))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 1.0)
        let gap = try #require(SpatialMeasurement.measureGap(
            in: analyzer,
            from: red,
            to: blue,
            along: .vertical,
            at: 50,
            tolerance: 0
        ))
        #expect(abs(gap - 120.0) <= 1.0)
    }

    @Test("Spatial accuracy within 1pt at 2x Retina scale")
    func retinaAccuracy() throws {
        let marginPixels = 64
        let image = try #require(SyntheticImage.centeredBox(
            width: 400,
            height: 400,
            background: white,
            boxColor: black,
            boxRect: CGRect(
                x: marginPixels,
                y: marginPixels,
                width: 400 - 2 * marginPixels,
                height: 400 - 2 * marginPixels
            )
        ))
        let analyzer = ImageAnalyzer(image: image, scaleFactor: 2.0)
        let distance = try #require(SpatialMeasurement.measureEdge(
            in: analyzer,
            from: CGPoint(x: 0, y: 100),
            direction: .right,
            targetColor: black,
            tolerance: 0
        ))
        let expectedPt: CGFloat = 32.0
        #expect(abs(distance - expectedPt) <= 1.0)
    }
}
