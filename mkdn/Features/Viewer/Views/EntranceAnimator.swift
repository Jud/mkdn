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
        var coverLayers: [CALayer] = []
        var cleanupTask: Task<Void, Never>?

        // MARK: - Constants

        static let driftDistance: CGFloat = 8

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

            // Only cover fragments within or near the viewport.
            let viewportMaxY: CGFloat = if let scrollView = textView.enclosingScrollView {
                scrollView.contentView.bounds.maxY
            } else {
                textView.visibleRect.maxY
            }
            let coverLimit = viewportMaxY + 100

            // Stagger relative to viewport height, not full document height,
            // to avoid compressing delays on long documents.
            let docHeight = max(viewportMaxY, 1)

            if textView.textLayoutManager != nil {
                let blockGroups = enumerateAndCoverFragments(
                    viewLayer: viewLayer,
                    textView: textView,
                    elapsed: elapsed,
                    docHeight: docHeight,
                    coverLimit: coverLimit
                )

                processBlockGroups(
                    blockGroups,
                    elapsed: elapsed,
                    staggerHeight: docHeight,
                    in: textView,
                    to: viewLayer
                )
            } else {
                enumerateAndCoverLinesTextKit1(
                    viewLayer: viewLayer,
                    textView: textView,
                    elapsed: elapsed,
                    docHeight: docHeight,
                    coverLimit: coverLimit
                )
            }
        }

        // MARK: - Fragment Enumeration

        private func enumerateAndCoverFragments(
            viewLayer: CALayer,
            textView: NSTextView,
            elapsed: CFTimeInterval,
            docHeight: CGFloat,
            coverLimit: CGFloat
        ) -> [String: BlockGroup] {
            guard let layoutManager = textView.textLayoutManager,
                  let contentManager = layoutManager.textContentManager,
                  let textStorage = textView.textStorage
            else { return [:] }

            var blockGroups: [String: BlockGroup] = [:]

            layoutManager.enumerateTextLayoutFragments(
                from: layoutManager.documentRange.location,
                options: [.ensuresLayout]
            ) { fragment in
                let frame = fragment.layoutFragmentFrame
                guard frame.origin.y <= coverLimit else { return false }

                let delay = self.positionDelay(y: frame.origin.y, documentHeight: docHeight)
                guard elapsed < delay + AnimationConstants.fadeInDuration else { return true }

                let groupID = self.blockGroupID(
                    for: fragment, contentManager: contentManager, textStorage: textStorage
                )

                if let groupID {
                    blockGroups[groupID, default: BlockGroup(minY: frame.origin.y)]
                        .frames.append(frame)
                } else {
                    let coverLayer = self.makeCoverLayer(for: fragment, in: textView)
                    self.addCoverAnimation(to: coverLayer, positionDelay: delay, elapsed: elapsed)
                    viewLayer.addSublayer(coverLayer)
                    self.coverLayers.append(coverLayer)
                    self.recordAttachmentDelay(
                        fragment: fragment,
                        positionDelay: delay,
                        elapsed: elapsed,
                        contentManager: contentManager,
                        textStorage: textStorage
                    )
                }
                return true
            }

            return blockGroups
        }

        // MARK: - TextKit 1 Line Enumeration

        /// Creates cover layers using TextKit 1's `NSLayoutManager` line fragment
        /// enumeration. Used for text views that don't have a `textLayoutManager`
        /// (e.g. the code file viewer with horizontal scrolling).
        private func enumerateAndCoverLinesTextKit1(
            viewLayer: CALayer,
            textView: NSTextView,
            elapsed: CFTimeInterval,
            docHeight: CGFloat,
            coverLimit: CGFloat
        ) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return }

            let origin = textView.textContainerOrigin
            let visibleWidth = textView.enclosingScrollView?
                .contentView.bounds.width ?? textView.bounds.width
            let glyphRange = layoutManager.glyphRange(for: textContainer)

            layoutManager.enumerateLineFragments(
                forGlyphRange: glyphRange
            ) { rect, _, _, _, stop in
                guard rect.origin.y <= coverLimit else {
                    stop.pointee = true
                    return
                }

                let delay = self.positionDelay(
                    y: rect.origin.y, documentHeight: docHeight
                )
                guard elapsed < delay + AnimationConstants.fadeInDuration
                else { return }

                let layer = CALayer()
                layer.frame = CGRect(
                    x: origin.x,
                    y: rect.origin.y + origin.y,
                    width: visibleWidth,
                    height: rect.height
                )
                layer.backgroundColor = textView.backgroundColor.cgColor
                layer.zPosition = 1

                self.addCoverAnimation(
                    to: layer, positionDelay: delay, elapsed: elapsed
                )
                viewLayer.addSublayer(layer)
                self.coverLayers.append(layer)
            }
        }

        // MARK: - Block Group Processing

        private func processBlockGroups(
            _ groups: [String: BlockGroup],
            elapsed: CFTimeInterval,
            staggerHeight: CGFloat,
            in textView: NSTextView,
            to viewLayer: CALayer
        ) {
            let docHeight = staggerHeight

            for (groupID, group) in groups {
                if groupID.hasPrefix("table-") {
                    let positionDelay = positionDelay(
                        y: group.minY, documentHeight: docHeight
                    )
                    let tableRangeID = String(groupID.dropFirst("table-".count))
                    tableDelays[tableRangeID] = max(positionDelay - elapsed, 0)
                    let coverLayer = makeBlockGroupCoverLayer(
                        frames: group.frames, in: textView
                    )
                    addCoverAnimation(
                        to: coverLayer, positionDelay: positionDelay, elapsed: elapsed
                    )
                    viewLayer.addSublayer(coverLayer)
                    coverLayers.append(coverLayer)
                } else {
                    // Code blocks: per-line covers for line-by-line cascade.
                    addCodeBlockLineCoverLayers(
                        group: group,
                        elapsed: elapsed,
                        docHeight: docHeight,
                        in: textView,
                        to: viewLayer
                    )
                }
            }
        }

        /// Creates one cover layer per line within a code block, each with its
        /// own position-based stagger delay. The last line's cover extends down
        /// to include the code block's bottom padding.
        private func addCodeBlockLineCoverLayers(
            group: BlockGroup,
            elapsed: CFTimeInterval,
            docHeight: CGFloat,
            in textView: NSTextView,
            to viewLayer: CALayer
        ) {
            let origin = textView.textContainerOrigin
            let containerWidth =
                textView.textContainer?.size.width ?? textView.bounds.width
            let sortedFrames = group.frames.sorted { $0.origin.y < $1.origin.y }

            for (index, frame) in sortedFrames.enumerated() {
                let positionDelay = positionDelay(
                    y: frame.origin.y, documentHeight: docHeight
                )

                var coverHeight = frame.height
                if index == sortedFrames.count - 1 {
                    coverHeight += CodeBlockBackgroundTextView.bottomPadding
                }

                let layer = CALayer()
                layer.frame = CGRect(
                    x: origin.x,
                    y: frame.origin.y + origin.y,
                    width: containerWidth,
                    height: coverHeight
                )
                layer.backgroundColor = textView.backgroundColor.cgColor
                layer.zPosition = 1

                addCoverAnimation(
                    to: layer, positionDelay: positionDelay, elapsed: elapsed
                )
                viewLayer.addSublayer(layer)
                coverLayers.append(layer)
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
    }
#endif
