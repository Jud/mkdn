#if os(macOS)
    import AppKit

    /// Layout observation for ``OverlayCoordinator``.
    extension OverlayCoordinator {
        func observeLayoutChanges(on textView: NSTextView) {
            guard layoutObserver == nil else { return }
            textView.postsFrameChangedNotifications = true
            layoutObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.repositionOverlays()
                }
            }
        }

        func observeScrollChanges(on textView: NSTextView) {
            guard scrollObserver == nil,
                  let clipView = textView.enclosingScrollView?.contentView
            else { return }
            clipView.postsBoundsChangedNotifications = true
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.repositionOverlays()
                }
            }
        }

        func removeObservers() {
            for observer in [layoutObserver, scrollObserver].compactMap(\.self) {
                NotificationCenter.default.removeObserver(observer)
            }
            layoutObserver = nil
            scrollObserver = nil
        }
    }
#endif
