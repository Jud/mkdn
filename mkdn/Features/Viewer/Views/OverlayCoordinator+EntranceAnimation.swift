#if os(macOS)
    import AppKit

    /// Entrance animation synchronization for ``OverlayCoordinator``.
    extension OverlayCoordinator {
        /// Syncs overlay NSView alpha animations to cover-layer stagger timing.
        ///
        /// Sets each overlay's `alphaValue` to 0 and schedules a fade-in
        /// animation matching the entrance animator's per-fragment delay, so
        /// overlay views appear in sync with their corresponding cover-layer
        /// fade rather than popping in at full opacity.
        func applyEntranceAnimation(
            attachmentDelays: [ObjectIdentifier: CFTimeInterval],
            tableDelays: [String: CFTimeInterval],
            fadeInDuration: CFTimeInterval
        ) {
            for (_, entry) in entries {
                let delay: CFTimeInterval? = if let attachment = entry.attachment {
                    attachmentDelays[ObjectIdentifier(attachment)]
                } else if let tableRangeID = entry.tableRangeID {
                    tableDelays[tableRangeID]
                } else {
                    nil
                }

                guard let delay else { continue }

                entry.view.alphaValue = 0
                entry.highlightOverlay?.alphaValue = 0

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = fadeInDuration
                        context.timingFunction = CAMediaTimingFunction(
                            name: .easeOut
                        )
                        entry.view.animator().alphaValue = 1
                        entry.highlightOverlay?.animator().alphaValue = 1
                    }
                }
            }
        }
    }
#endif
