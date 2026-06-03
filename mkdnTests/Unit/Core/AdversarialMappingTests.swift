import Foundation
import Testing
@testable import mkdnLib

/// Mapping soundness (I5) and the resolver's tolerance of hostile ranges (B2).
@MainActor
@Suite("Comment adversarial mapping")
struct AdversarialMappingTests {
    private func resolver(_ raw: String) -> (CommentRangeResolver, TextStorageResult) {
        let document = CriticMarkup.preprocess(raw)
        let blocks = MarkdownRenderer.render(text: document.transformedSource, theme: .solarizedDark)
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)
        return (CommentRangeResolver(document: document, sourceMap: result.sourceMap), result)
    }

    @Test("B2: hostile / degenerate NSRanges resolve to nil without trapping", arguments: [
        NSRange(location: Int.max, length: 1),
        NSRange(location: Int.max, length: Int.max),
        NSRange(location: NSNotFound, length: 0),
        NSRange(location: -1, length: 5),
        NSRange(location: 5, length: -1),
        NSRange(location: 0, length: 0),
        NSRange(location: 1_000_000, length: 10),
    ])
    func rejectsHostileRanges(range: NSRange) {
        let (resolver, _) = resolver("The quick brown fox.")
        #expect(resolver.rawRange(forBuilderRange: range) == nil)
    }

    @Test("I5: every plain-prose word selection maps to exactly that text in raw")
    func plainProseMapsExactly() {
        let docs = ["The quick brown fox", "alpha beta gamma delta", "one two three four five"]
        for raw in docs {
            let (resolver, result) = resolver(raw)
            let rendered = result.attributedString.string as NSString
            for word in raw.split(separator: " ").map(String.init) {
                let nsRange = rendered.range(of: word)
                guard nsRange.location != NSNotFound else { continue }
                if let r = resolver.rawRange(forBuilderRange: nsRange) {
                    #expect(raw[r] == word, "wrong mapping for \(word) in \(raw)")
                }
            }
        }
    }

    @Test("I5: random sub-ranges never map to a wrong slice (soundness, not nil-ness)")
    func randomSubRangesSound() {
        let raw = "The quick brown fox jumps over the lazy dog near the river"
        let (resolver, result) = resolver(raw)
        let rendered = result.attributedString.string as NSString
        for seed in UInt64(0) ..< 300 {
            var rng = SeededRNG(seed: seed)
            let len = rendered.length
            guard len > 1 else { continue }
            let loc = Int(rng.next() % UInt64(len))
            let maxLen = len - loc
            let length = 1 + Int(rng.next() % UInt64(maxLen))
            let nsRange = NSRange(location: loc, length: length)
            guard let r = resolver.rawRange(forBuilderRange: nsRange) else { continue }
            // Soundness: the resolved raw slice's text must equal the selected
            // rendered text (this doc is pure prose → linear 1:1 mapping).
            let selected = rendered.substring(with: nsRange)
            #expect(raw[r] == selected, "seed \(seed): \(nsRange) selected \"\(selected)\" mapped \"\(raw[r])\"")
        }
    }

    @Test("Support matrix: unmappable selections resolve to nil, never crash")
    func unmappableSelectionsAreNil() {
        // A selection that spans a paragraph boundary is not source-contiguous.
        let (resolver, result) = resolver("first para\n\nsecond para")
        let whole = NSRange(location: 0, length: (result.attributedString.string as NSString).length)
        #expect(resolver.rawRange(forBuilderRange: whole) == nil)
    }
}
