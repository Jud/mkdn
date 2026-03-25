#if os(macOS)
    import AppKit

    /// Entrance animation synchronization for ``OverlayCoordinator``.
    extension OverlayCoordinator {
        /// Syncs overlay NSView alpha animations to cover-layer stagger timing.
        ///
        /// Sets each overlay's `alphaValue` to 0 and schedules a fade-in
        /// animation matching the entrance animator's position-based delay, so
        /// overlay views appear in sync with their corresponding cover-layer
        /// fade rather than popping in at full opacity.
        ///
        /// Delays in the map are pre-adjusted for elapsed time — they represent
        /// the remaining delay from now until the overlay should start fading in.
        /// This makes the method safe to call after relayout.
        func applyEntranceAnimation(
            attachmentDelays: [ObjectIdentifier: CFTimeInterval],
            fadeInDuration: CFTimeInterval
        ) {
            for (_, entry) in entries {
                guard let attachment = entry.attachment,
                      let delay = attachmentDelays[ObjectIdentifier(attachment)]
                else { continue }

                entry.view.alphaValue = 0

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = fadeInDuration
                        context.timingFunction = CAMediaTimingFunction(
                            name: .easeOut
                        )
                        entry.view.animator().alphaValue = 1
                    }
                }
            }
        }
    }
#endif
