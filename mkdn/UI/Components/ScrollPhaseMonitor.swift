import AppKit
import SwiftUI

/// Custom `NSView` that intercepts scroll wheel events and delegates
/// to a closure for classification and handling.
///
/// Does not call `super.scrollWheel` -- forwarding is handled explicitly
/// by the coordinator via `nextResponder`.
final class ScrollPhaseMonitorView: NSView {
    var onScrollEvent: ((NSEvent) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        if let handler = onScrollEvent {
            handler(event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
}

/// Momentum-aware scroll event interceptor for Mermaid diagram panning.
///
/// An `NSViewRepresentable` wrapping `ScrollPhaseMonitorView` that uses
/// `GestureIntentClassifier` and `DiagramPanState` to distinguish between
/// diagram-pan and document-scroll gestures. Fresh scroll gestures pan the
/// diagram; momentum-carry and pass-through gestures are forwarded up the
/// responder chain to the parent `ScrollView`.
///
/// Follows the same `NSViewRepresentable` + `NSView` subclass pattern as
/// `WindowAccessor` / `WindowAccessorView`.
struct ScrollPhaseMonitor: NSViewRepresentable {
    /// Natural (unscaled) size of the diagram image.
    let contentSize: CGSize

    /// Current zoom scale applied to the diagram.
    let zoomScale: CGFloat

    /// Two-way binding to the parent view's pan offset state.
    @Binding var panOffset: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(panOffset: $panOffset)
    }

    func makeNSView(context: Context) -> ScrollPhaseMonitorView {
        let view = ScrollPhaseMonitorView()
        let coordinator = context.coordinator
        coordinator.contentSize = contentSize
        coordinator.zoomScale = zoomScale
        view.onScrollEvent = { [weak view] event in
            guard let view else { return }
            coordinator.handleScrollEvent(event, in: view)
        }
        return view
    }

    func updateNSView(_: ScrollPhaseMonitorView, context: Context) {
        let coordinator = context.coordinator
        coordinator.contentSize = contentSize
        coordinator.zoomScale = zoomScale
        coordinator.panOffset = $panOffset

        if panOffset != coordinator.panState.offset {
            coordinator.panState.offset = panOffset
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {
        var classifier = GestureIntentClassifier()
        var panState = DiagramPanState()
        var contentSize: CGSize = .zero
        var zoomScale: CGFloat = 1.0
        var panOffset: Binding<CGSize>

        init(panOffset: Binding<CGSize>) {
            self.panOffset = panOffset
        }

        func handleScrollEvent(_ event: NSEvent, in view: NSView) {
            let frameSize = view.bounds.size
            guard frameSize.width > 0, frameSize.height > 0 else {
                view.nextResponder?.scrollWheel(with: event)
                return
            }

            let fittedSize = aspectFitSize(
                imageSize: contentSize,
                frameSize: frameSize
            )
            let contentFitsInFrame = fittedSize.width * zoomScale <= frameSize.width
                && fittedSize.height * zoomScale <= frameSize.height

            let verdict = classifier.classify(
                phase: event.phase,
                momentumPhase: event.momentumPhase,
                contentFitsInFrame: contentFitsInFrame
            )

            switch verdict {
            case .panDiagram:
                let result = panState.applyDelta(
                    dx: event.scrollingDeltaX,
                    dy: event.scrollingDeltaY,
                    contentSize: fittedSize,
                    frameSize: frameSize,
                    zoomScale: zoomScale
                )
                panOffset.wrappedValue = panState.offset

                let hasOverflow = result.overflowDelta.width != 0
                    || result.overflowDelta.height != 0
                if hasOverflow {
                    view.nextResponder?.scrollWheel(with: event)
                }

            case .passThrough:
                view.nextResponder?.scrollWheel(with: event)
            }
        }

        /// Compute the size of the image after aspect-fit scaling into the frame.
        ///
        /// This gives the effective content size at zoom scale 1.0, which is needed
        /// for boundary clamping in `DiagramPanState`.
        private func aspectFitSize(
            imageSize: CGSize,
            frameSize: CGSize
        ) -> CGSize {
            guard imageSize.width > 0, imageSize.height > 0 else {
                return .zero
            }
            let imageAspect = imageSize.width / imageSize.height
            let frameAspect = frameSize.width / frameSize.height
            if imageAspect > frameAspect {
                return CGSize(
                    width: frameSize.width,
                    height: frameSize.width / imageAspect
                )
            }
            return CGSize(
                width: frameSize.height * imageAspect,
                height: frameSize.height
            )
        }
    }
}
