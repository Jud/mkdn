import AppKit
import QuartzCore

/// Per-layout-fragment staggered entrance animation for the preview text view.
///
/// When a document is loaded or reloaded, ``EntranceAnimator`` applies a
/// staggered fade-in cascade to each text layout fragment as it enters the
/// viewport. Each fragment is revealed by fading out a background-colored
/// cover layer, and the text view content drifts upward from a slight offset
/// to its final position.
///
/// The stagger delay and cap use ``AnimationConstants/staggerDelay`` and
/// ``AnimationConstants/staggerCap``. The fade-in duration matches
/// ``AnimationConstants/fadeIn`` (0.5s, ease-out). The upward drift distance
/// is 8pt, matching the current SwiftUI entrance animation.
///
/// When the system Reduce Motion preference is enabled, fragments appear
/// immediately with no animation.
@MainActor
final class EntranceAnimator {
    // MARK: - Public State

    var isAnimating = false
    weak var textView: NSTextView?

    // MARK: - Private State

    private var animatedFragments: Set<ObjectIdentifier> = []
    private var fragmentIndex = 0
    private var reduceMotion = false
    private var coverLayers: [CALayer] = []
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Constants

    private static let fadeInDuration: CFTimeInterval = 0.5
    private static let driftDistance: CGFloat = 8

    // MARK: - Lifecycle

    /// Prepares for a full document entrance animation.
    ///
    /// Clears all fragment tracking, removes existing cover layers, and
    /// starts a new entrance sequence. When `reduceMotion` is true,
    /// fragments appear immediately with no animation.
    func beginEntrance(reduceMotion: Bool) {
        cleanupTask?.cancel()
        removeCoverLayers()
        removeViewDriftAnimation()

        animatedFragments.removeAll()
        fragmentIndex = 0
        self.reduceMotion = reduceMotion

        if reduceMotion {
            isAnimating = false
            return
        }

        isAnimating = true
        applyViewDriftAnimation()
        scheduleCleanup()
    }

    /// Resets animation state, removing all cover layers and fragment tracking.
    func reset() {
        cleanupTask?.cancel()
        removeCoverLayers()
        removeViewDriftAnimation()

        animatedFragments.removeAll()
        fragmentIndex = 0
        isAnimating = false
    }

    // MARK: - Fragment Animation

    /// Enumerates all layout fragments from the text layout manager and
    /// applies cover-layer entrance animation to each one.
    ///
    /// Call this after setting attributed string content on the text view
    /// so that TextKit 2 has completed layout and fragments are available.
    func animateVisibleFragments() {
        guard isAnimating, !reduceMotion else { return }
        guard let textView,
              let layoutManager = textView.textLayoutManager
        else { return }

        layoutManager.enumerateTextLayoutFragments(
            from: layoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            animateFragment(fragment)
            return true
        }
    }

    private func animateFragment(_ fragment: NSTextLayoutFragment) {
        let fragmentID = ObjectIdentifier(fragment)
        guard !animatedFragments.contains(fragmentID) else { return }
        animatedFragments.insert(fragmentID)

        guard isAnimating, !reduceMotion else { return }
        guard let textView, let viewLayer = textView.layer else { return }

        let coverLayer = makeCoverLayer(
            for: fragment,
            in: textView
        )

        let delay = min(
            Double(fragmentIndex) * AnimationConstants.staggerDelay,
            AnimationConstants.staggerCap
        )
        fragmentIndex += 1

        applyCoverFadeAnimation(to: coverLayer, delay: delay)
        viewLayer.addSublayer(coverLayer)
        coverLayers.append(coverLayer)
    }

    // MARK: - Cover Layer

    private func makeCoverLayer(
        for fragment: NSTextLayoutFragment,
        in textView: NSTextView
    ) -> CALayer {
        let frame = fragment.layoutFragmentFrame
        let origin = textView.textContainerOrigin
        let adjustedFrame = frame.offsetBy(dx: origin.x, dy: origin.y)

        let layer = CALayer()
        layer.frame = adjustedFrame
        layer.backgroundColor = textView.backgroundColor.cgColor
        layer.zPosition = 1
        return layer
    }

    private func applyCoverFadeAnimation(
        to layer: CALayer,
        delay: CFTimeInterval
    ) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.0
        animation.duration = Self.fadeInDuration
        animation.beginTime = CACurrentMediaTime() + delay
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .both

        layer.opacity = 0
        layer.add(animation, forKey: "coverFade")
    }

    // MARK: - View Drift

    private func applyViewDriftAnimation() {
        guard let layer = textView?.layer else { return }

        let driftTransform = CATransform3DMakeTranslation(
            0, Self.driftDistance, 0
        )
        let totalDuration =
            AnimationConstants.staggerCap + Self.fadeInDuration

        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = NSValue(caTransform3D: driftTransform)
        animation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        animation.duration = totalDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        layer.transform = CATransform3DIdentity
        layer.add(animation, forKey: "entranceDrift")
    }

    private func removeViewDriftAnimation() {
        guard let layer = textView?.layer else { return }
        layer.removeAnimation(forKey: "entranceDrift")
        layer.transform = CATransform3DIdentity
    }

    // MARK: - Cleanup

    private func removeCoverLayers() {
        for layer in coverLayers {
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        }
        coverLayers.removeAll()
    }

    private func scheduleCleanup() {
        cleanupTask?.cancel()
        let totalDuration =
            AnimationConstants.staggerCap + Self.fadeInDuration + 0.1
        cleanupTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(totalDuration))
            guard !Task.isCancelled else { return }
            self?.removeCoverLayers()
            self?.isAnimating = false
        }
    }
}
