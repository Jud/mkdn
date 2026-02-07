import Foundation
import Testing

@testable import mkdnLib

@Suite("DiagramPanState")
struct DiagramPanStateTests {
    // Content 200x200 at 2x zoom = 400x400 effective, frame 300x300.
    // maxOffset = (400 - 300) / 2 = 50 per axis.
    private static let largeContent = CGSize(width: 200, height: 200)
    private static let standardFrame = CGSize(width: 300, height: 300)
    private static let standardZoom: CGFloat = 2.0

    @Test("Delta within bounds consumed fully with zero overflow")
    func deltaWithinBoundsConsumedFully() {
        var state = DiagramPanState()

        let result = state.applyDelta(
            dx: 10,
            dy: 15,
            contentSize: Self.largeContent,
            frameSize: Self.standardFrame,
            zoomScale: Self.standardZoom
        )

        #expect(result.consumedDelta.width == 10)
        #expect(result.consumedDelta.height == 15)
        #expect(result.overflowDelta.width == 0)
        #expect(result.overflowDelta.height == 0)
        #expect(state.offset.width == 10)
        #expect(state.offset.height == 15)
    }

    @Test("Delta at positive boundary produces overflow")
    func deltaAtPositiveBoundaryProducesOverflow() {
        var state = DiagramPanState()

        // maxOffset is 50. Apply 80 -> consume 50, overflow 30.
        let result = state.applyDelta(
            dx: 80,
            dy: 80,
            contentSize: Self.largeContent,
            frameSize: Self.standardFrame,
            zoomScale: Self.standardZoom
        )

        #expect(result.consumedDelta.width == 50)
        #expect(result.consumedDelta.height == 50)
        #expect(result.overflowDelta.width == 30)
        #expect(result.overflowDelta.height == 30)
        #expect(state.offset.width == 50)
        #expect(state.offset.height == 50)
    }

    @Test("Delta at negative boundary produces overflow")
    func deltaAtNegativeBoundaryProducesOverflow() {
        var state = DiagramPanState()

        // maxOffset is 50. Apply -80 -> consume -50, overflow -30.
        let result = state.applyDelta(
            dx: -80,
            dy: -80,
            contentSize: Self.largeContent,
            frameSize: Self.standardFrame,
            zoomScale: Self.standardZoom
        )

        #expect(result.consumedDelta.width == -50)
        #expect(result.consumedDelta.height == -50)
        #expect(result.overflowDelta.width == -30)
        #expect(result.overflowDelta.height == -30)
        #expect(state.offset.width == -50)
        #expect(state.offset.height == -50)
    }

    @Test("Content smaller than frame produces all overflow (BR-05)")
    func contentSmallerThanFrameAllOverflow() {
        var state = DiagramPanState()

        // Content 100x100 at 1x = 100x100, frame 300x300.
        // maxOffset = max(0, (100 - 300) / 2) = 0. All delta overflows.
        let result = state.applyDelta(
            dx: 25,
            dy: -15,
            contentSize: CGSize(width: 100, height: 100),
            frameSize: Self.standardFrame,
            zoomScale: 1.0
        )

        #expect(result.consumedDelta.width == 0)
        #expect(result.consumedDelta.height == 0)
        #expect(result.overflowDelta.width == 25)
        #expect(result.overflowDelta.height == -15)
        #expect(state.offset == .zero)
    }

    @Test("Zoom scale affects pannable boundary (larger zoom = more pan range)")
    func zoomScaleAffectsBoundary() {
        var state = DiagramPanState()

        // Content 200x200 at 1x = 200x200, frame 300x300.
        // maxOffset = max(0, (200 - 300) / 2) = 0. No panning at 1x.
        let resultNoZoom = state.applyDelta(
            dx: 10,
            dy: 10,
            contentSize: Self.largeContent,
            frameSize: Self.standardFrame,
            zoomScale: 1.0
        )

        #expect(resultNoZoom.consumedDelta.width == 0)
        #expect(resultNoZoom.overflowDelta.width == 10)

        // Same content at 3x = 600x600, frame 300x300.
        // maxOffset = (600 - 300) / 2 = 150. Now 10 is within bounds.
        let resultZoomed = state.applyDelta(
            dx: 10,
            dy: 10,
            contentSize: Self.largeContent,
            frameSize: Self.standardFrame,
            zoomScale: 3.0
        )

        #expect(resultZoomed.consumedDelta.width == 10)
        #expect(resultZoomed.overflowDelta.width == 0)
    }

    @Test("Successive deltas accumulate offset until boundary")
    func successiveDeltasAccumulate() {
        var state = DiagramPanState()

        // maxOffset = 50 per axis. Apply 30, then 30 more.
        // First: consume 30, offset becomes 30.
        let first = state.applyDelta(
            dx: 30,
            dy: 0,
            contentSize: Self.largeContent,
            frameSize: Self.standardFrame,
            zoomScale: Self.standardZoom
        )

        #expect(first.consumedDelta.width == 30)
        #expect(first.overflowDelta.width == 0)
        #expect(state.offset.width == 30)

        // Second: offset 30 + 30 = 60, clamped to 50. Consumed 20, overflow 10.
        let second = state.applyDelta(
            dx: 30,
            dy: 0,
            contentSize: Self.largeContent,
            frameSize: Self.standardFrame,
            zoomScale: Self.standardZoom
        )

        #expect(second.consumedDelta.width == 20)
        #expect(second.overflowDelta.width == 10)
        #expect(state.offset.width == 50)
    }

    @Test("Mixed axis clamping works independently")
    func mixedAxisClamping() {
        var state = DiagramPanState()

        // maxOffset = 50 per axis.
        // dx = 10 (within bounds), dy = 80 (exceeds boundary).
        let result = state.applyDelta(
            dx: 10,
            dy: 80,
            contentSize: Self.largeContent,
            frameSize: Self.standardFrame,
            zoomScale: Self.standardZoom
        )

        #expect(result.consumedDelta.width == 10)
        #expect(result.overflowDelta.width == 0)
        #expect(result.consumedDelta.height == 50)
        #expect(result.overflowDelta.height == 30)
    }

    @Test("Initial offset is zero")
    func initialOffsetIsZero() {
        let state = DiagramPanState()

        #expect(state.offset == .zero)
    }
}
