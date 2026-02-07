import AppKit
import Testing

@testable import mkdnLib

@Suite("GestureIntentClassifier")
struct GestureIntentClassifierTests {
    @Test("Fresh gesture over diagram produces panDiagram (BR-02)")
    func freshGestureProducesPan() {
        var classifier = GestureIntentClassifier()

        let verdict = classifier.classify(
            phase: .began,
            momentumPhase: [],
            contentFitsInFrame: false
        )

        #expect(verdict == .panDiagram)
        #expect(classifier.gestureState == .panning)
    }

    @Test("Momentum event produces passThrough (BR-03)")
    func momentumEventPassesThrough() {
        var classifier = GestureIntentClassifier()

        let verdict = classifier.classify(
            phase: [],
            momentumPhase: .changed,
            contentFitsInFrame: false
        )

        #expect(verdict == .passThrough)
    }

    @Test("Momentum event during began phase still passes through (BR-03 precedence)")
    func momentumTakesPrecedenceOverBegan() {
        var classifier = GestureIntentClassifier()

        let verdict = classifier.classify(
            phase: .began,
            momentumPhase: .began,
            contentFitsInFrame: false
        )

        #expect(verdict == .passThrough)
    }

    @Test("Gesture started outside stays passThrough through changed (BR-01)")
    func gestureStartedOutsideStaysPassThrough() {
        var classifier = GestureIntentClassifier()

        // Simulate a gesture that started outside: the monitor receives
        // .changed without ever seeing .began for this view.
        let verdict = classifier.classify(
            phase: .changed,
            momentumPhase: [],
            contentFitsInFrame: false
        )

        #expect(verdict == .passThrough)
        #expect(classifier.gestureState == .passingThrough)
    }

    @Test("Content fits in frame always produces passThrough (BR-05)")
    func contentFitsInFramePassesThrough() {
        var classifier = GestureIntentClassifier()

        let verdict = classifier.classify(
            phase: .began,
            momentumPhase: [],
            contentFitsInFrame: true
        )

        #expect(verdict == .passThrough)
        #expect(classifier.gestureState == .passingThrough)
    }

    @Test("Gesture sequence resets on ended, next began classified fresh")
    func gestureResetsOnEnded() {
        var classifier = GestureIntentClassifier()

        // Start a pan gesture
        _ = classifier.classify(
            phase: .began,
            momentumPhase: [],
            contentFitsInFrame: false
        )
        #expect(classifier.gestureState == .panning)

        // End the gesture
        let endVerdict = classifier.classify(
            phase: .ended,
            momentumPhase: [],
            contentFitsInFrame: false
        )
        #expect(endVerdict == .passThrough)
        #expect(classifier.gestureState == .idle)

        // Next fresh gesture should classify independently
        let freshVerdict = classifier.classify(
            phase: .began,
            momentumPhase: [],
            contentFitsInFrame: false
        )
        #expect(freshVerdict == .panDiagram)
        #expect(classifier.gestureState == .panning)
    }

    @Test("Gesture sequence resets on cancelled")
    func gestureResetsOnCancelled() {
        var classifier = GestureIntentClassifier()

        _ = classifier.classify(
            phase: .began,
            momentumPhase: [],
            contentFitsInFrame: false
        )
        #expect(classifier.gestureState == .panning)

        let cancelVerdict = classifier.classify(
            phase: .cancelled,
            momentumPhase: [],
            contentFitsInFrame: false
        )
        #expect(cancelVerdict == .passThrough)
        #expect(classifier.gestureState == .idle)
    }

    @Test("Pan gesture stays pan through changed events (sticky verdict)")
    func panStickyThroughChanged() {
        var classifier = GestureIntentClassifier()

        // Begin panning
        let beganVerdict = classifier.classify(
            phase: .began,
            momentumPhase: [],
            contentFitsInFrame: false
        )
        #expect(beganVerdict == .panDiagram)

        // Subsequent changed events stay pan
        for _ in 0 ..< 5 {
            let changedVerdict = classifier.classify(
                phase: .changed,
                momentumPhase: [],
                contentFitsInFrame: false
            )
            #expect(changedVerdict == .panDiagram)
        }

        #expect(classifier.gestureState == .panning)
    }

    @Test("PassThrough stays passThrough through changed events (sticky verdict)")
    func passThroughStickyThroughChanged() {
        var classifier = GestureIntentClassifier()

        // Begin with content fitting in frame -> pass-through
        let beganVerdict = classifier.classify(
            phase: .began,
            momentumPhase: [],
            contentFitsInFrame: true
        )
        #expect(beganVerdict == .passThrough)

        // Subsequent changed events stay pass-through even if content no longer fits
        for _ in 0 ..< 5 {
            let changedVerdict = classifier.classify(
                phase: .changed,
                momentumPhase: [],
                contentFitsInFrame: false
            )
            #expect(changedVerdict == .passThrough)
        }

        #expect(classifier.gestureState == .passingThrough)
    }

    @Test("MayBegin phase produces passThrough")
    func mayBeginPassesThrough() {
        var classifier = GestureIntentClassifier()

        let verdict = classifier.classify(
            phase: .mayBegin,
            momentumPhase: [],
            contentFitsInFrame: false
        )

        #expect(verdict == .passThrough)
    }
}
