import Foundation
import Testing
@testable import mkdnLib

@Suite("Snap Logic")
struct SnapLogicTests {
    @Test("Ratio near 0.5 snaps to 0.5")
    func snapsToHalf() {
        let result = snappedSplitRatio(proposedRatio: 0.51, totalWidth: 1_000)
        #expect(result == 0.5)
    }

    @Test("Ratio near 0.3 snaps to 0.3")
    func snapsToThirty() {
        let result = snappedSplitRatio(proposedRatio: 0.31, totalWidth: 1_000)
        #expect(result == 0.3)
    }

    @Test("Ratio near 0.7 snaps to 0.7")
    func snapsToSeventy() {
        let result = snappedSplitRatio(proposedRatio: 0.69, totalWidth: 1_000)
        #expect(result == 0.7)
    }

    @Test("Ratio outside snap range stays at dragged value")
    func noSnapOutsideThreshold() {
        let result = snappedSplitRatio(proposedRatio: 0.4, totalWidth: 1_000)
        #expect(result == 0.4)
    }

    @Test("Ratio is clamped to respect minimum pane width on left")
    func clampsToMinPaneWidthLeft() {
        let result = snappedSplitRatio(proposedRatio: 0.1, totalWidth: 1_000, minPaneWidth: 200)
        #expect(result == 0.2)
    }

    @Test("Ratio is clamped to respect minimum pane width on right")
    func clampsToMinPaneWidthRight() {
        let result = snappedSplitRatio(proposedRatio: 0.95, totalWidth: 1_000, minPaneWidth: 200)
        #expect(result == 0.8)
    }

    @Test("Zero total width returns default ratio")
    func zeroWidthReturnsDefault() {
        let result = snappedSplitRatio(proposedRatio: 0.3, totalWidth: 0)
        #expect(result == 0.5)
    }
}
