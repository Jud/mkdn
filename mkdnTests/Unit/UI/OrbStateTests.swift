import SwiftUI
import Testing
@testable import mkdnLib

@Suite("OrbState")
struct OrbStateTests {
    // MARK: - Priority Ordering

    @Test("fileChanged has highest priority")
    func fileChangedIsHighest() {
        #expect(OrbState.fileChanged > .defaultHandler)
        #expect(OrbState.fileChanged > .idle)
    }

    @Test("defaultHandler outranks idle")
    func defaultHandlerAboveIdle() {
        #expect(OrbState.defaultHandler > .idle)
    }

    @Test("max of multiple active states returns highest priority")
    func maxResolution() {
        let states: [OrbState] = [.defaultHandler, .fileChanged]
        #expect(states.max() == .fileChanged)

        let lowerTwo: [OrbState] = [.idle, .defaultHandler]
        #expect(lowerTwo.max() == .defaultHandler)
    }

    @Test("empty state array resolves to nil (idle via ?? .idle)")
    func emptyResolvesToNil() {
        let states: [OrbState] = []
        #expect(states.max() == nil)
    }

    // MARK: - Visibility

    @Test("idle is not visible")
    func idleNotVisible() {
        #expect(!OrbState.idle.isVisible)
    }

    @Test("all non-idle states are visible")
    func nonIdleStatesVisible() {
        #expect(OrbState.defaultHandler.isVisible)
        #expect(OrbState.fileChanged.isVisible)
    }

    // MARK: - Color Mapping

    @Test("defaultHandler returns orbDefaultHandlerColor")
    func defaultHandlerColor() {
        #expect(OrbState.defaultHandler.color == AnimationConstants.orbDefaultHandlerColor)
    }

    @Test("fileChanged returns orbFileChangedColor")
    func fileChangedColor() {
        #expect(OrbState.fileChanged.color == AnimationConstants.orbFileChangedColor)
    }

    @Test("idle falls back to orbDefaultHandlerColor")
    func idleColor() {
        #expect(OrbState.idle.color == AnimationConstants.orbDefaultHandlerColor)
    }

    @Test("each non-idle state has a distinct color")
    func distinctColors() {
        let colors = [OrbState.defaultHandler.color, OrbState.fileChanged.color]
        let unique = Set(colors.map { "\($0)" })
        #expect(unique.count == 2)
    }
}
