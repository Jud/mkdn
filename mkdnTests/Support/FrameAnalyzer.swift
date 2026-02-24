import CoreGraphics
import Foundation

// MARK: - Result Types

/// Measurable animation property extracted from pixel data.
enum AnimatableProperty: Sendable {
    /// Average brightness (0--1) in the region.
    case opacity

    /// Horizontal extent of non-background content in the region.
    case scaleX

    /// Vertical extent of non-background content in the region.
    case scaleY

    /// Vertical center of non-background content in the region.
    case positionY
}

/// Inferred animation curve type.
enum AnimationCurve: Sendable, Equatable {
    case easeIn
    case easeOut
    case easeInOut
    case linear
    case spring
}

/// Result of breathing orb pulse analysis.
struct PulseAnalysis: Sendable {
    /// Detected oscillation frequency.
    let cyclesPerMinute: Double

    /// `true` when amplitude is below the detection threshold.
    let isStationary: Bool

    /// Min and max combined RGB brightness across analyzed frames.
    let amplitudeRange: ClosedRange<Double>
}

/// Result of a color transition duration measurement.
struct TransitionAnalysis: Sendable {
    /// Measured transition duration in seconds.
    let duration: TimeInterval

    /// Inferred curve type from the progress shape.
    let curve: AnimationCurve
}

/// Result of spring animation curve fitting.
struct SpringAnalysis: Sendable {
    /// Time from start to first peak (approximate spring response).
    let response: TimeInterval

    /// Estimated damping fraction from overshoot magnitude.
    let dampingFraction: Double

    /// Time from start until the property stays within 2% of target.
    let settleTime: TimeInterval
}

// MARK: - FrameAnalyzer

/// Analyzes sequences of captured frames to extract animation timing curves.
///
/// Each analysis method operates on the stored frame array and uses
/// ``ImageAnalyzer`` for per-frame pixel sampling. All point and rect
/// parameters use the point coordinate system (matching
/// ``CGWindowListCreateImage`` output at the given scale factor).
struct FrameAnalyzer: Sendable {
    let frames: [CGImage]
    let fps: Int
    let scaleFactor: CGFloat

    /// Time in seconds between consecutive frames.
    var frameDuration: TimeInterval {
        1.0 / Double(fps)
    }

    // MARK: - Orb Pulse Detection

    /// Measures sinusoidal brightness oscillation in the orb region.
    ///
    /// Computes combined RGB brightness for each frame, then counts
    /// local peaks to determine cycle frequency. Uses hysteresis to
    /// avoid counting noise as peaks. An amplitude below the
    /// `stationaryThreshold` marks the orb as stationary (Reduce
    /// Motion compliance).
    func measureOrbPulse(
        orbRegion: CGRect,
        stationaryThreshold: Double = 10.0
    ) -> PulseAnalysis {
        let series = brightnessSeries(in: orbRegion)

        guard let minVal = series.min(),
              let maxVal = series.max()
        else {
            return PulseAnalysis(
                cyclesPerMinute: 0,
                isStationary: true,
                amplitudeRange: 0 ... 0
            )
        }

        let amplitude = maxVal - minVal

        if amplitude < stationaryThreshold {
            return PulseAnalysis(
                cyclesPerMinute: 0,
                isStationary: true,
                amplitudeRange: minVal ... maxVal
            )
        }

        let peaks = countPeaks(series, hysteresis: amplitude * 0.15)

        let totalSeconds = Double(frames.count) / Double(fps)
        let cycles = Double(peaks)
        let cpm = totalSeconds > 0 ? (cycles / totalSeconds) * 60.0 : 0

        return PulseAnalysis(
            cyclesPerMinute: cpm,
            isStationary: false,
            amplitudeRange: minVal ... maxVal
        )
    }

    // MARK: - Transition Duration

    /// Measures how long a color transition takes in a region.
    ///
    /// For each frame, computes a progress value (0 = at `startColor`,
    /// 1 = at `endColor`) using color distance ratios. The duration
    /// spans from the first frame exceeding 10% progress to the first
    /// frame reaching 90% progress.
    func measureTransitionDuration(
        region: CGRect,
        startColor: PixelColor,
        endColor: PixelColor
    ) -> TransitionAnalysis {
        let progress = frames.map { frame -> Double in
            let analyzer = ImageAnalyzer(
                image: frame,
                scaleFactor: scaleFactor
            )
            let color = analyzer.averageColor(in: region)
            let toStart = Double(color.distance(to: startColor))
            let toEnd = Double(color.distance(to: endColor))
            let total = toStart + toEnd
            guard total > 0 else { return 0 }
            return toStart / total
        }

        let startThreshold = 0.1
        let endThreshold = 0.9
        var startFrame = 0
        var endFrame = progress.count - 1

        for (idx, progressValue) in progress.enumerated()
            where progressValue >= startThreshold
        {
            startFrame = idx
            break
        }

        for (idx, progressValue) in progress.enumerated()
            where progressValue >= endThreshold
        {
            endFrame = idx
            break
        }

        let durationSec = Double(endFrame - startFrame) / Double(fps)
        let curve = inferCurve(
            progress,
            startFrame: startFrame,
            endFrame: endFrame
        )

        return TransitionAnalysis(duration: durationSec, curve: curve)
    }

    // MARK: - Spring Curve Fitting

    /// Estimates spring parameters from property values across frames.
    ///
    /// Tracks the specified ``AnimatableProperty`` for each frame,
    /// identifies overshoot and settling behavior, and estimates
    /// approximate `response` and `dampingFraction` values.
    func measureSpringCurve(
        region: CGRect,
        property: AnimatableProperty
    ) -> SpringAnalysis {
        let values = extractPropertyValues(
            region: region,
            property: property
        )

        guard values.count > 2 else {
            return SpringAnalysis(
                response: 0, dampingFraction: 1, settleTime: 0
            )
        }

        let tailCount = max(1, values.count / 10)
        let target = values.suffix(tailCount)
            .reduce(0.0, +) / Double(tailCount)

        guard let firstValue = values.first,
              abs(target - firstValue) > 0.001
        else {
            return SpringAnalysis(
                response: 0, dampingFraction: 1, settleTime: 0
            )
        }

        let peak = findOvershootPeak(
            values, target: target, firstValue: firstValue
        )

        let responseTime = Double(peak.frame) / Double(fps)
        let damping = estimateDamping(
            overshootRatio: peak.ratio
        )
        let settleTime = findSettleTime(
            values, target: target, firstValue: firstValue
        )

        return SpringAnalysis(
            response: responseTime,
            dampingFraction: damping,
            settleTime: settleTime
        )
    }

    // MARK: - Stagger Delay Measurement

    /// Measures the appearance timing of multiple regions.
    ///
    /// For each region, finds the first frame where the average color
    /// differs from `background` by more than `threshold` distance.
    /// Returns absolute delays from the earliest appearance.
    func measureStaggerDelays(
        regions: [CGRect],
        revealColor _: PixelColor,
        background: PixelColor,
        threshold: Int = 20
    ) -> [TimeInterval] {
        let appearanceFrames = regions.map { region -> Int in
            for (idx, frame) in frames.enumerated() {
                let analyzer = ImageAnalyzer(
                    image: frame,
                    scaleFactor: scaleFactor
                )
                let color = analyzer.averageColor(in: region)

                if color.distance(to: background) > threshold {
                    return idx
                }
            }
            return frames.count - 1
        }

        guard let earliest = appearanceFrames.min() else { return [] }

        return appearanceFrames.map { frame in
            Double(frame - earliest) / Double(fps)
        }
    }
}

// MARK: - Private Helpers

private extension FrameAnalyzer {
    func countPeaks(_ series: [Double], hysteresis: Double) -> Int {
        guard series.count > 2 else { return 0 }

        var peaks = 0
        var lastExtreme = series[0]
        var rising = series.count > 1 && series[1] > series[0]

        for idx in 1 ..< series.count {
            if rising {
                if series[idx] < lastExtreme - hysteresis {
                    peaks += 1
                    lastExtreme = series[idx]
                    rising = false
                } else if series[idx] > lastExtreme {
                    lastExtreme = series[idx]
                }
            } else {
                if series[idx] > lastExtreme + hysteresis {
                    lastExtreme = series[idx]
                    rising = true
                } else if series[idx] < lastExtreme {
                    lastExtreme = series[idx]
                }
            }
        }

        return peaks
    }

    func brightnessSeries(in region: CGRect) -> [Double] {
        frames.map { frame in
            let analyzer = ImageAnalyzer(
                image: frame,
                scaleFactor: scaleFactor
            )
            let color = analyzer.averageColor(in: region)
            return Double(color.red) + Double(color.green)
                + Double(color.blue)
        }
    }

    func extractPropertyValues(
        region: CGRect,
        property: AnimatableProperty
    ) -> [Double] {
        frames.map { frame in
            let analyzer = ImageAnalyzer(
                image: frame,
                scaleFactor: scaleFactor
            )
            switch property {
            case .opacity:
                let color = analyzer.averageColor(in: region)
                let sum = Double(color.red) + Double(color.green)
                    + Double(color.blue)
                return sum / (3.0 * 255.0)
            case .scaleX:
                let bg = analyzer.sampleColor(at: .zero)
                return analyzer.contentBounds(
                    background: bg, tolerance: 10
                ).width
            case .scaleY:
                let bg = analyzer.sampleColor(at: .zero)
                return analyzer.contentBounds(
                    background: bg, tolerance: 10
                ).height
            case .positionY:
                let bg = analyzer.sampleColor(at: .zero)
                return analyzer.contentBounds(
                    background: bg, tolerance: 10
                ).midY
            }
        }
    }

    func inferCurve(
        _ progress: [Double],
        startFrame: Int,
        endFrame: Int
    ) -> AnimationCurve {
        guard endFrame > startFrame + 2 else { return .linear }

        let midFrame = (startFrame + endFrame) / 2
        let actualMid = progress[midFrame]
        let threshold = 0.15

        if actualMid > 0.5 + threshold {
            return .easeOut
        }
        if actualMid < 0.5 - threshold {
            return .easeIn
        }
        return .easeInOut
    }

    func findOvershootPeak(
        _ values: [Double],
        target: Double,
        firstValue: Double
    ) -> (frame: Int, ratio: Double) {
        let direction = (target - firstValue).sign == .plus ? 1.0 : -1.0
        let range = abs(target - firstValue)
        var maxOvershoot = 0.0
        var peakFrame = 0

        for (idx, val) in values.enumerated() {
            let overshoot = (val - target) * direction
            if overshoot > maxOvershoot {
                maxOvershoot = overshoot
                peakFrame = idx
            }
        }

        let ratio = range > 0 ? maxOvershoot / range : 0
        return (frame: peakFrame, ratio: ratio)
    }

    func estimateDamping(overshootRatio: Double) -> Double {
        guard overshootRatio > 0 else { return 1.0 }
        let logOS = log(overshootRatio)
        let damping = -logOS / sqrt(.pi * .pi + logOS * logOS)
        return min(max(damping, 0), 1)
    }

    func findSettleTime(
        _ values: [Double],
        target: Double,
        firstValue: Double
    ) -> TimeInterval {
        let range = abs(target - firstValue)
        let threshold = max(range * 0.05, 0.001)
        var settleFrame = 0

        for idx in stride(from: values.count - 1, through: 0, by: -1)
            where abs(values[idx] - target) > threshold
        {
            settleFrame = idx + 1
            break
        }

        return Double(settleFrame) / Double(fps)
    }
}
