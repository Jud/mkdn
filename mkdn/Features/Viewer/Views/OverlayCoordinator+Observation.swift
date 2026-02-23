import AppKit
import SwiftUI

/// Layout observation and sticky header management for ``OverlayCoordinator``.
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
                self?.handleScrollBoundsChange()
            }
        }
    }

    func handleScrollBoundsChange() {
        guard let textView,
              let scrollView = textView.enclosingScrollView
        else { return }
        let visibleRect = scrollView.contentView.bounds
        let headerHeight = stickyHeaderHeight()
        for (blockIndex, entry) in entries {
            guard case let .table(columns, _) = entry.block,
                  let columnWidths = entry.cellMap?.columnWidths
            else { continue }
            let tableFrame = entry.view.frame
            guard tableFrame.height > visibleRect.height else {
                stickyHeaders[blockIndex]?.isHidden = true
                continue
            }
            let headerBottom = tableFrame.origin.y + headerHeight
            let tableBottom = tableFrame.origin.y + tableFrame.height
            if visibleRect.origin.y > headerBottom,
               visibleRect.origin.y < tableBottom - headerHeight
            {
                if stickyHeaders[blockIndex] == nil, let appSettings {
                    let header = TableHeaderView(columns: columns, columnWidths: columnWidths)
                    let hosting = NSHostingView(rootView: header.environment(appSettings))
                    textView.addSubview(hosting)
                    stickyHeaders[blockIndex] = hosting
                }
                stickyHeaders[blockIndex]?.frame = CGRect(
                    x: tableFrame.origin.x,
                    y: visibleRect.origin.y,
                    width: tableFrame.width,
                    height: headerHeight
                )
                stickyHeaders[blockIndex]?.isHidden = false
            } else {
                stickyHeaders[blockIndex]?.isHidden = true
            }
        }
    }

    func stickyHeaderHeight() -> CGFloat {
        let baseFont = PlatformTypeConverter.bodyFont(scaleFactor: appSettings?.scaleFactor ?? 1.0)
        let font = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        return ceil(font.ascender - font.descender + font.leading)
            + 2 * TableColumnSizer.verticalCellPadding + TableColumnSizer.headerDividerHeight
    }

    func removeObservers() {
        for observer in [layoutObserver, scrollObserver].compactMap(\.self) {
            NotificationCenter.default.removeObserver(observer)
        }
        layoutObserver = nil
        scrollObserver = nil
    }
}
