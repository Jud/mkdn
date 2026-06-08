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
            ) { [weak self, weak textView] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.onFrameChange?()
                    // LiveResizeScrollView already repositioned overlays
                    // synchronously from tile() — for window resize and the
                    // comment-rail resize alike; skip the duplicate pass but
                    // keep onFrameChange so the scroll-spy heading cache still
                    // invalidates on width changes.
                    guard !self.isInLiveResize,
                          (textView as? CodeBlockBackgroundTextView)?
                          .sidebarResizeAnchor == nil
                    else { return }
                    self.repositionOverlays()
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
            ) { [weak self, weak textView] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.onScrollChange?()
                    // tile()'s anchor restore moves the scroll origin during a
                    // comment-rail resize and repositions overlays itself after its
                    // trailing viewport layout; skip the duplicate this bounds change
                    // would otherwise post.
                    guard (textView as? CodeBlockBackgroundTextView)?
                        .sidebarResizeAnchor == nil
                    else { return }
                    self.repositionOverlays()
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
