import CoreGraphics
import Testing
@testable import mkdnLib

// MARK: - Synthetic Frame Sequences

private enum SyntheticFrames {
    static func pulseSequence(
        frameCount: Int,
        cycleFrames: Int,
        width: Int = 100,
        height: Int = 100,
        orbRect: CGRect = CGRect(x: 30, y: 30, width: 40, height: 40),
        minBrightness: UInt8 = 50,
        maxBrightness: UInt8 = 200,
        background: PixelColor = PixelColor(red: 0, green: 0, blue: 0)
    ) -> [CGImage] {
        (0 ..< frameCount).compactMap { idx in
            let phase = Double(idx) / Double(cycleFrames) * 2.0 * .pi
            let raw = (sin(phase) + 1.0) / 2.0
            let minB = Double(minBrightness)
            let maxB = Double(maxBrightness)
            let bright = UInt8(minB + (maxB - minB) * raw)
            let orbColor = PixelColor(
                red: bright, green: bright, blue: bright
            )
            return SyntheticImage.centeredBox(
                width: width,
                height: height,
                background: background,
                boxColor: orbColor,
                boxRect: orbRect
            )
        }
    }

    static func transitionSequence(
        frameCount: Int,
        startColor: PixelColor,
        endColor: PixelColor,
        transitionStart: Int,
        transitionEnd: Int,
        width: Int = 100,
        height: Int = 100
    ) -> [CGImage] {
        (0 ..< frameCount).compactMap { idx in
            let color: PixelColor
            if idx < transitionStart {
                color = startColor
            } else if idx >= transitionEnd {
                color = endColor
            } else {
                let denom = transitionEnd - transitionStart
                let blend = Double(idx - transitionStart) / Double(denom)
                color = interpolateColor(startColor, endColor, blend: blend)
            }
            return SyntheticImage.solidColor(
                width: width, height: height, color: color
            )
        }
    }

    static func staggerSequence(
        frameCount: Int,
        regions: [CGRect],
        appearanceFrames: [Int],
        revealColor: PixelColor,
        background: PixelColor,
        width: Int = 200,
        height: Int = 200
    ) -> [CGImage] {
        (0 ..< frameCount).compactMap { idx in
            guard let context = createContext(
                width: width, height: height
            )
            else { return nil }

            let bgCG = cgColor(from: background)
            context.setFillColor(bgCG)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            for (regionIdx, region) in regions.enumerated()
                where idx >= appearanceFrames[regionIdx]
            {
                context.setFillColor(cgColor(from: revealColor))
                context.fill(region)
            }

            return context.makeImage()
        }
    }

    private static func interpolateColor(
        _ colorA: PixelColor,
        _ colorB: PixelColor,
        blend: Double
    ) -> PixelColor {
        let clampedT = min(max(blend, 0), 1)
        let invT = 1.0 - clampedT

        return PixelColor(
            red: UInt8(Double(colorA.red) * invT + Double(colorB.red) * clampedT),
            green: UInt8(Double(colorA.green) * invT + Double(colorB.green) * clampedT),
            blue: UInt8(Double(colorA.blue) * invT + Double(colorB.blue) * clampedT)
        )
    }

    private static let deviceRGB = CGColorSpaceCreateDeviceRGB()

    private static func createContext(
        width: Int,
        height: Int
    ) -> CGContext? {
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: deviceRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        return ctx
    }

    private static func cgColor(from pixel: PixelColor) -> CGColor {
        let comps: [CGFloat] = [
            CGFloat(pixel.red) / 255,
            CGFloat(pixel.green) / 255,
            CGFloat(pixel.blue) / 255,
            CGFloat(pixel.alpha) / 255,
        ]
        return CGColor(
            colorSpace: deviceRGB, components: comps
        ) ?? CGColor(gray: 0, alpha: 1)
    }
}

// MARK: - Tests

@Suite("FrameAnalyzer")
struct FrameAnalyzerTests {
    @Test("Pulse detection with sinusoidal brightness returns correct CPM")
    func detectsSinusoidalPulse() {
        let cycleFrames = 30
        let totalFrames = 90
        let fps = 30

        let frames = SyntheticFrames.pulseSequence(
            frameCount: totalFrames,
            cycleFrames: cycleFrames
        )

        let analyzer = FrameAnalyzer(
            frames: frames, fps: fps, scaleFactor: 1.0
        )
        let orbRegion = CGRect(x: 30, y: 30, width: 40, height: 40)
        let result = analyzer.measureOrbPulse(orbRegion: orbRegion)

        #expect(!result.isStationary)
        #expect(result.amplitudeRange.upperBound > result.amplitudeRange.lowerBound)

        let expectedCPM = 60.0 / (Double(cycleFrames) / Double(fps))
        #expect(abs(result.cyclesPerMinute - expectedCPM) < expectedCPM * 0.25)
    }

    @Test("Stationary orb detected when brightness is constant")
    func detectsStationaryOrb() {
        let solidColor = PixelColor(red: 100, green: 100, blue: 100)
        let background = PixelColor(red: 0, green: 0, blue: 0)
        let frameCount = 60

        let frames = (0 ..< frameCount).compactMap { _ in
            SyntheticImage.centeredBox(
                width: 100,
                height: 100,
                background: background,
                boxColor: solidColor,
                boxRect: CGRect(x: 30, y: 30, width: 40, height: 40)
            )
        }

        let analyzer = FrameAnalyzer(
            frames: frames, fps: 30, scaleFactor: 1.0
        )
        let result = analyzer.measureOrbPulse(
            orbRegion: CGRect(x: 30, y: 30, width: 40, height: 40)
        )

        #expect(result.isStationary)
        #expect(result.cyclesPerMinute == 0)
    }

    @Test("Transition duration measurement matches known transition")
    func measuresTransitionDuration() {
        let fps = 60
        let transitionStart = 10
        let transitionEnd = 31
        let totalFrames = 60
        let startColor = PixelColor(red: 0, green: 0, blue: 0)
        let endColor = PixelColor(red: 255, green: 255, blue: 255)

        let frames = SyntheticFrames.transitionSequence(
            frameCount: totalFrames,
            startColor: startColor,
            endColor: endColor,
            transitionStart: transitionStart,
            transitionEnd: transitionEnd
        )

        let analyzer = FrameAnalyzer(
            frames: frames, fps: fps, scaleFactor: 1.0
        )
        let region = CGRect(x: 10, y: 10, width: 80, height: 80)
        let result = analyzer.measureTransitionDuration(
            region: region,
            startColor: startColor,
            endColor: endColor
        )

        let fullDuration = Double(transitionEnd - transitionStart)
            / Double(fps)
        let expected10to90 = fullDuration * 0.8
        let tolerance = 4.0 / Double(fps)
        #expect(abs(result.duration - expected10to90) < tolerance)
    }

    @Test("Stagger delays reflect region appearance order")
    func measuresStaggerDelays() {
        let fps = 60
        let totalFrames = 60
        let background = PixelColor(red: 0, green: 0, blue: 0)
        let reveal = PixelColor(red: 200, green: 200, blue: 200)

        let regions = [
            CGRect(x: 10, y: 10, width: 30, height: 30),
            CGRect(x: 10, y: 60, width: 30, height: 30),
            CGRect(x: 10, y: 110, width: 30, height: 30),
        ]
        let appearances = [5, 11, 17]

        let frames = SyntheticFrames.staggerSequence(
            frameCount: totalFrames,
            regions: regions,
            appearanceFrames: appearances,
            revealColor: reveal,
            background: background
        )

        let analyzer = FrameAnalyzer(
            frames: frames, fps: fps, scaleFactor: 1.0
        )
        let delays = analyzer.measureStaggerDelays(
            regions: regions,
            revealColor: reveal,
            background: background
        )

        #expect(delays.count == 3)
        #expect(delays[0] == 0)

        let expectedDelay1 = Double(appearances[1] - appearances[0])
            / Double(fps)
        let expectedDelay2 = Double(appearances[2] - appearances[0])
            / Double(fps)
        let tolerance = 1.0 / Double(fps)

        #expect(abs(delays[1] - expectedDelay1) <= tolerance)
        #expect(abs(delays[2] - expectedDelay2) <= tolerance)
    }

    @Test("Spring curve detects overshoot")
    func detectsSpringOvershoot() {
        let fps = 60
        let frameCount = 60
        let background = PixelColor(red: 0, green: 0, blue: 0)
        let target: Double = 150

        let frames: [CGImage] = (0 ..< frameCount).compactMap { idx in
            let elapsed = Double(idx) / 10.0
            let spring = 1.0 - exp(-3.0 * elapsed) * cos(8.0 * elapsed)
            let raw = min(max(spring * target, 0), 255)
            let bright = UInt8(raw)
            let color = PixelColor(
                red: bright, green: bright, blue: bright
            )
            return SyntheticImage.centeredBox(
                width: 100,
                height: 100,
                background: background,
                boxColor: color,
                boxRect: CGRect(x: 20, y: 20, width: 60, height: 60)
            )
        }

        let analyzer = FrameAnalyzer(
            frames: frames, fps: fps, scaleFactor: 1.0
        )
        let result = analyzer.measureSpringCurve(
            region: CGRect(x: 20, y: 20, width: 60, height: 60),
            property: .opacity
        )

        #expect(result.dampingFraction < 1.0)
        #expect(result.response > 0)
        #expect(result.settleTime > result.response)
    }
}
