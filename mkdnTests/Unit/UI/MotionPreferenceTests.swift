import Testing

@testable import mkdnLib

@Suite("MotionPreference")
struct MotionPreferenceTests {
    @Test("Allows continuous animation when reduceMotion is false")
    func continuousAllowed() {
        let pref = MotionPreference(reduceMotion: false)
        #expect(pref.allowsContinuousAnimation)
    }

    @Test("Disables continuous animation when reduceMotion is true")
    func continuousDisabled() {
        let pref = MotionPreference(reduceMotion: true)
        #expect(!pref.allowsContinuousAnimation)
    }

    @Test("Stagger delay is zero with reduceMotion")
    func staggerZeroWithReduceMotion() {
        let pref = MotionPreference(reduceMotion: true)
        #expect(pref.staggerDelay == 0)
    }

    @Test("Stagger delay is standard without reduceMotion")
    func staggerStandardWithoutReduceMotion() {
        let pref = MotionPreference(reduceMotion: false)
        #expect(pref.staggerDelay == AnimationConstants.staggerDelay)
    }

    @Test("Continuous primitives return nil with reduceMotion")
    func continuousPrimitivesNilWithReduceMotion() {
        let pref = MotionPreference(reduceMotion: true)
        #expect(pref.resolved(.breathe) == nil)
        #expect(pref.resolved(.haloBloom) == nil)
    }

    @Test("Non-continuous primitives return non-nil with reduceMotion")
    func nonContinuousNonNilWithReduceMotion() {
        let pref = MotionPreference(reduceMotion: true)
        #expect(pref.resolved(.springSettle) != nil)
        #expect(pref.resolved(.gentleSpring) != nil)
        #expect(pref.resolved(.quickSettle) != nil)
        #expect(pref.resolved(.fadeIn) != nil)
        #expect(pref.resolved(.fadeOut) != nil)
        #expect(pref.resolved(.crossfade) != nil)
        #expect(pref.resolved(.quickFade) != nil)
    }

    @Test("All primitives return non-nil without reduceMotion")
    func allPrimitivesNonNilWithoutReduceMotion() {
        let pref = MotionPreference(reduceMotion: false)
        #expect(pref.resolved(.breathe) != nil)
        #expect(pref.resolved(.haloBloom) != nil)
        #expect(pref.resolved(.springSettle) != nil)
        #expect(pref.resolved(.gentleSpring) != nil)
        #expect(pref.resolved(.quickSettle) != nil)
        #expect(pref.resolved(.fadeIn) != nil)
        #expect(pref.resolved(.fadeOut) != nil)
        #expect(pref.resolved(.crossfade) != nil)
        #expect(pref.resolved(.quickFade) != nil)
    }
}
