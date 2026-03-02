#if os(macOS)
    import AppKit
    import QuartzCore

    // MARK: - Cover Layer Animation

    extension EntranceAnimator {
        /// Adds a fade animation to a cover layer, accounting for elapsed time.
        ///
        /// If the entrance started some time ago, the cover starts at a partially
        /// faded opacity and runs for the remaining duration only. This keeps
        /// covers visually consistent after relayout.
        func addCoverAnimation(
            to layer: CALayer,
            positionDelay: CFTimeInterval,
            elapsed: CFTimeInterval
        ) {
            let remainingDelay = max(positionDelay - elapsed, 0)

            // How far into this cover's fade are we?
            let fadeElapsed = max(elapsed - positionDelay, 0)
            let fadeDuration = AnimationConstants.fadeInDuration
            let fadeProgress = min(fadeElapsed / fadeDuration, 1)
            let startOpacity = Float(1.0 - fadeProgress)
            let remainingFade = fadeDuration * (1.0 - fadeProgress)

            guard remainingFade > 0.01 else {
                // Already fully revealed — no animation needed.
                layer.opacity = 0
                return
            }

            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = startOpacity
            animation.toValue = 0.0
            animation.duration = remainingFade
            animation.beginTime = CACurrentMediaTime() + remainingDelay
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.fillMode = .both

            layer.opacity = 0
            layer.add(animation, forKey: "coverFade")
        }

        // MARK: - Cover Layers

        func makeCoverLayer(
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

        func makeBlockGroupCoverLayer(
            frames: [CGRect],
            in textView: NSTextView
        ) -> CALayer {
            let origin = textView.textContainerOrigin
            let containerWidth =
                textView.textContainer?.size.width ?? textView.bounds.width
            let union = frames.reduce(frames[0]) { $0.union($1) }

            let margin: CGFloat = 1

            let layer = CALayer()
            layer.frame = CGRect(
                x: origin.x - margin,
                y: union.minY + origin.y - margin,
                width: containerWidth + 2 * margin,
                height: union.height + 2 * margin
            )
            layer.backgroundColor = textView.backgroundColor.cgColor
            layer.zPosition = 1
            return layer
        }

        // MARK: - View Drift

        func applyViewDriftAnimation() {
            guard let layer = textView?.layer else { return }

            let driftTransform = CATransform3DMakeTranslation(
                0, Self.driftDistance, 0
            )
            let totalDuration =
                AnimationConstants.staggerCap + AnimationConstants.fadeInDuration

            let animation = CABasicAnimation(keyPath: "transform")
            animation.fromValue = NSValue(caTransform3D: driftTransform)
            animation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
            animation.duration = totalDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

            layer.transform = CATransform3DIdentity
            layer.add(animation, forKey: "entranceDrift")
        }

        func removeViewDriftAnimation() {
            guard let layer = textView?.layer else { return }
            layer.removeAnimation(forKey: "entranceDrift")
            layer.transform = CATransform3DIdentity
        }

        // MARK: - Cleanup

        func removeCoverLayers() {
            for layer in coverLayers {
                layer.removeAllAnimations()
                layer.removeFromSuperlayer()
            }
            coverLayers.removeAll()
        }

        func scheduleCleanup() {
            cleanupTask?.cancel()
            let totalDuration =
                AnimationConstants.staggerCap + AnimationConstants.fadeInDuration + 0.1
            cleanupTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(totalDuration))
                guard !Task.isCancelled else { return }
                self?.removeCoverLayers()
                self?.isAnimating = false
            }
        }
    }
#endif
