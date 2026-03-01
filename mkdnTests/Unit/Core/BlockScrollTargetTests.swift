import SwiftUI
import Testing
@testable import mkdnLib

@Suite("BlockScrollTarget")
struct BlockScrollTargetTests {
    @Test("default anchor is .top")
    func defaultAnchor() {
        let target = BlockScrollTarget(blockIndex: 5)

        #expect(target.blockIndex == 5)
        #expect(target.anchor == .top)
    }

    @Test("custom anchor is stored correctly")
    func customAnchor() {
        let target = BlockScrollTarget(blockIndex: 3, anchor: .center)

        #expect(target.blockIndex == 3)
        #expect(target.anchor == .center)
    }

    @Test("Equatable: equal targets")
    func equalTargets() {
        let target1 = BlockScrollTarget(blockIndex: 2, anchor: .bottom)
        let target2 = BlockScrollTarget(blockIndex: 2, anchor: .bottom)

        #expect(target1 == target2)
    }

    @Test("Equatable: different blockIndex")
    func differentBlockIndex() {
        let target1 = BlockScrollTarget(blockIndex: 1)
        let target2 = BlockScrollTarget(blockIndex: 2)

        #expect(target1 != target2)
    }

    @Test("Equatable: different anchor")
    func differentAnchor() {
        let target1 = BlockScrollTarget(blockIndex: 1, anchor: .top)
        let target2 = BlockScrollTarget(blockIndex: 1, anchor: .center)

        #expect(target1 != target2)
    }

    @Test("Equatable: both defaults are equal")
    func bothDefaultsEqual() {
        let target1 = BlockScrollTarget(blockIndex: 0)
        let target2 = BlockScrollTarget(blockIndex: 0)

        #expect(target1 == target2)
    }
}
