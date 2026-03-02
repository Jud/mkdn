#if os(macOS)
    import AppKit
    import QuartzCore

    /// Position-based staggered entrance animation for the preview text view.
    ///
    /// When a document is loaded or reloaded, ``EntranceAnimator`` applies a
    /// staggered fade-in cascade driven by each fragment's Y position. Each
    /// fragment is revealed by fading out a background-colored cover layer, and
    /// the text view content drifts upward from a slight offset to its final
    /// position.
    ///
    /// Code block and table fragments are grouped by block ID and share a single
    /// full-width cover layer that hides both the container (background + border)
    /// and text, so each code block or table fades in as a unit.
    ///
    /// The animation is **position-based and idempotent**: calling
    /// ``animateVisibleFragments()`` after a layout shift (e.g. overlay height
    /// change) tears down existing covers and rebuilds them for the current
    /// layout, adjusting timing for elapsed time. This makes the system
    /// inherently relayout-proof.
    ///
    /// When the system Reduce Motion preference is enabled, fragments appear
    /// immediately with no animation.
    @MainActor
    final class EntranceAnimator {
        // MARK: - Public State

        var isAnimating = false
        weak var textView: NSTextView?
        private(set) var attachmentDelays: [ObjectIdentifier: CFTimeInterval] = [:]
        private(set) var tableDelays: [String: CFTimeInterval] = [:]

        // MARK: - Private State

        private var entranceStartTime: CFTimeInterval = 0
        private var reduceMotion = false
        private var coverLayers: [CALayer] = []
        private var cleanupTask: Task<Void, Never>?

        // MARK: - Constants

        private static let driftDistance: CGFloat = 8

        // MARK: - Types

        private struct BlockGroup {
            let minY: CGFloat
            var frames: [CGRect] = []
        }

        // MARK: - Lifecycle

        /// Prepares for a full document entrance animation.
        ///
        /// Clears all cover layers and starts a new entrance sequence. When
        /// `reduceMotion` is true, fragments appear immediately with no animation.
        func beginEntrance(reduceMotion: Bool) {
            cleanupTask?.cancel()
            removeCoverLayers()
            removeViewDriftAnimation()

            attachmentDelays.removeAll()
            tableDelays.removeAll()
            self.reduceMotion = reduceMotion

            if reduceMotion {
                isAnimating = false
                return
            }

            entranceStartTime = CACurrentMediaTime()
            isAnimating = true
            applyViewDriftAnimation()
            scheduleCleanup()
        }

        /// Resets animation state, removing all cover layers.
        func reset() {
            cleanupTask?.cancel()
            removeCoverLayers()
            removeViewDriftAnimation()

            attachmentDelays.removeAll()
            tableDelays.removeAll()
            isAnimating = false
        }

        // MARK: - Fragment Animation

        /// Rebuilds cover layers for the current layout state.
        ///
        /// This method is **idempotent**: it tears down all existing covers and
        /// recreates them from scratch based on the current fragment positions and
        /// elapsed time since the entrance started. Safe to call after layout
        /// shifts (overlay height changes, window resize) without accumulating
        /// stale state.
        ///
        /// Each fragment's stagger delay is computed from its Y position relative
        /// to the document height, giving a top-to-bottom cascade that is
        /// independent of fragment enumeration order.
        func animateVisibleFragments() {
            guard isAnimating, !reduceMotion else { return }
            guard let textView,
                  let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager,
                  let textStorage = textView.textStorage,
                  let viewLayer = textView.layer
            else { return }

            removeCoverLayers()
            attachmentDelays.removeAll()
            tableDelays.removeAll()

            let elapsed = CACurrentMediaTime() - entranceStartTime
            let totalRevealTime = AnimationConstants.staggerCap
                + AnimationConstants.fadeInDuration

            // Past the animation window — nothing to cover.
            guard elapsed < totalRevealTime else { return }

            // Compute document height for position-based stagger.
            let docHeight = documentHeight(
                layoutManager: layoutManager,
                contentManager: contentManager
            )

            var blockGroups: [String: BlockGroup] = [:]

            layoutManager.enumerateTextLayoutFragments(
                from: layoutManager.documentRange.location,
                options: [.ensuresLayout]
            ) { fragment in
                let frame = fragment.layoutFragmentFrame
                let positionDelay = self.positionDelay(
                    y: frame.origin.y, documentHeight: docHeight
                )

                // Skip fragments already fully revealed.
                if elapsed >= positionDelay + AnimationConstants.fadeInDuration {
                    return true
                }

                let groupID = self.blockGroupID(
                    for: fragment,
                    contentManager: contentManager,
                    textStorage: textStorage
                )

                if let groupID {
                    if var group = blockGroups[groupID] {
                        group.frames.append(frame)
                        blockGroups[groupID] = group
                    } else {
                        blockGroups[groupID] = BlockGroup(
                            minY: frame.origin.y,
                            frames: [frame]
                        )
                    }
                } else {
                    let coverLayer = self.makeCoverLayer(
                        for: fragment, in: textView
                    )
                    self.addCoverAnimation(
                        to: coverLayer,
                        positionDelay: positionDelay,
                        elapsed: elapsed
                    )
                    viewLayer.addSublayer(coverLayer)
                    self.coverLayers.append(coverLayer)

                    self.recordAttachmentDelay(
                        fragment: fragment,
                        positionDelay: positionDelay,
                        elapsed: elapsed,
                        contentManager: contentManager,
                        textStorage: textStorage
                    )
                }

                return true
            }

            processBlockGroups(
                blockGroups, elapsed: elapsed, in: textView, to: viewLayer
            )
        }

        // MARK: - Block Group Processing

        private func processBlockGroups(
            _ groups: [String: BlockGroup],
            elapsed: CFTimeInterval,
            in textView: NSTextView,
            to viewLayer: CALayer
        ) {
            let docHeight = documentHeight(textView: textView)

            for (groupID, group) in groups {
                let positionDelay = positionDelay(
                    y: group.minY, documentHeight: docHeight
                )

                if groupID.hasPrefix("table-") {
                    let tableRangeID = String(groupID.dropFirst("table-".count))
                    tableDelays[tableRangeID] = max(positionDelay - elapsed, 0)
                }

                let coverLayer = makeBlockGroupCoverLayer(
                    frames: group.frames, in: textView
                )
                addCoverAnimation(
                    to: coverLayer, positionDelay: positionDelay, elapsed: elapsed
                )
                viewLayer.addSublayer(coverLayer)
                coverLayers.append(coverLayer)
            }
        }

        // MARK: - Attachment Delay Recording

        private func recordAttachmentDelay(
            fragment: NSTextLayoutFragment,
            positionDelay: CFTimeInterval,
            elapsed: CFTimeInterval,
            contentManager: NSTextContentManager,
            textStorage: NSTextStorage
        ) {
            let docStart = contentManager.documentRange.location
            let fragStart = fragment.rangeInElement.location
            let charOffset = contentManager.offset(
                from: docStart, to: fragStart
            )
            if charOffset >= 0, charOffset < textStorage.length,
               let attachment = textStorage.attribute(
                   .attachment, at: charOffset, effectiveRange: nil
               ) as? NSTextAttachment
            {
                attachmentDelays[ObjectIdentifier(attachment)] =
                    max(positionDelay - elapsed, 0)
            }
        }

        // MARK: - Position-Based Stagger

        /// Computes stagger delay from a fragment's Y position.
        ///
        /// Maps the fragment's vertical position within the document to a delay
        /// in `[0, staggerCap]`. Fragments at the top start immediately;
        /// fragments at the bottom start at the stagger cap.
        private func positionDelay(
            y: CGFloat, documentHeight: CGFloat
        ) -> CFTimeInterval {
            guard documentHeight > 0 else { return 0 }
            let fraction = min(max(y / documentHeight, 0), 1)
            return fraction * AnimationConstants.staggerCap
        }

        private func documentHeight(textView: NSTextView) -> CGFloat {
            guard let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager
            else { return textView.bounds.height }
            return documentHeight(
                layoutManager: layoutManager, contentManager: contentManager
            )
        }

        private func documentHeight(
            layoutManager: NSTextLayoutManager,
            contentManager: NSTextContentManager
        ) -> CGFloat {
            var maxY: CGFloat = 0
            layoutManager.enumerateTextLayoutFragments(
                from: contentManager.documentRange.endLocation,
                options: [.reverse, .ensuresLayout]
            ) { fragment in
                maxY = fragment.layoutFragmentFrame.maxY
                return false
            }
            return max(maxY, 1)
        }

        // MARK: - Block Group Detection

        private func blockGroupID(
            for fragment: NSTextLayoutFragment,
            contentManager: NSTextContentManager,
            textStorage: NSTextStorage
        ) -> String? {
            let docStart = contentManager.documentRange.location
            let fragStart = fragment.rangeInElement.location
            let charOffset = contentManager.offset(from: docStart, to: fragStart)

            guard charOffset >= 0, charOffset < textStorage.length else {
                return nil
            }

            if let codeBlockID = textStorage.attribute(
                CodeBlockAttributes.range,
                at: charOffset,
                effectiveRange: nil
            ) as? String {
                return "code-\(codeBlockID)"
            }

            if let tableID = textStorage.attribute(
                TableAttributes.range,
                at: charOffset,
                effectiveRange: nil
            ) as? String {
                return "table-\(tableID)"
            }

            return nil
        }

        // MARK: - Cover Layer Animation

        /// Adds a fade animation to a cover layer, accounting for elapsed time.
        ///
        /// If the entrance started some time ago, the cover starts at a partially
        /// faded opacity and runs for the remaining duration only. This keeps
        /// covers visually consistent after relayout.
        private func addCoverAnimation(
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

        private func makeBlockGroupCoverLayer(
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

        private func applyViewDriftAnimation() {
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
