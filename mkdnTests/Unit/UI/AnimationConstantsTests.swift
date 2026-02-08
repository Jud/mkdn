import Testing

@testable import mkdnLib

@Suite("AnimationConstants")
struct AnimationConstantsTests {
    @Test("Stagger delay is 30ms")
    func staggerDelay() {
        #expect(AnimationConstants.staggerDelay == 0.03)
    }

    @Test("Stagger cap is 500ms")
    func staggerCap() {
        #expect(AnimationConstants.staggerCap == 0.5)
    }

    @Test("Hover scale factor is within subtle range")
    func hoverScale() {
        #expect(AnimationConstants.hoverScaleFactor > 1.0)
        #expect(AnimationConstants.hoverScaleFactor < 1.15)
    }

    @Test("Toolbar hover scale is within subtle range")
    func toolbarHoverScale() {
        #expect(AnimationConstants.toolbarHoverScale > 1.0)
        #expect(AnimationConstants.toolbarHoverScale < 1.15)
    }

    @Test("Toolbar hover scale is subtler than orb hover scale")
    func toolbarSubtlerThanOrb() {
        #expect(AnimationConstants.toolbarHoverScale < AnimationConstants.hoverScaleFactor)
    }

    @Test("Focus border width is 2pt")
    func focusBorderWidth() {
        #expect(AnimationConstants.focusBorderWidth == 2.0)
    }

    @Test("Focus glow radius is 6pt")
    func focusGlowRadius() {
        #expect(AnimationConstants.focusGlowRadius == 6.0)
    }

    @Test("Mermaid hover brightness is positive and subtle")
    func mermaidHoverBrightness() {
        #expect(AnimationConstants.mermaidHoverBrightness > 0)
        #expect(AnimationConstants.mermaidHoverBrightness < 0.1)
    }

    @Test("Stagger cap accommodates at least 10 blocks at stagger delay rate")
    func staggerCapAccommodatesBlocks() {
        let blocksBeforeCap = Int(AnimationConstants.staggerCap / AnimationConstants.staggerDelay)
        #expect(blocksBeforeCap >= 10)
    }
}
