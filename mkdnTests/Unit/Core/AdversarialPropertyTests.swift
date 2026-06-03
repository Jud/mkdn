import Foundation
import Testing
@testable import mkdnLib

/// Unicode/encoding sweep (cat C) and the combined property/op-sequence fuzz
/// (I1/I2/I4/I6/I9, cat E) — the catch-all for unknown-unknowns.
@Suite("Comment adversarial property")
struct AdversarialPropertyTests {
    @Test("Unicode comment spans and bodies round-trip", arguments: [
        ("wave 😀🎉 there", "😀🎉", "body with 😀 emoji and --> marker"),
        ("cafe\u{0301} time now", "cafe\u{0301}", "combining e\u{0301} note"),
        ("x \u{202E}rtl\u{202C} y", "rtl", "rtl \u{202E}body\u{202C}"),
        ("flag 🇺🇸 here", "🇺🇸", "regional indicator"),
        ("zero\u{200B}width join", "width", "zwsp body"),
    ])
    func unicodeAuthoringRoundTrips(text: String, span: String, body: String) {
        let doc = CommentFixture.doc(text, comment: span, id: "u1", body: body)
        let parsed = assertCommentInvariants(doc, Ctx(span))
        #expect(parsed.commentsByID["u1"]?.body == body)
        #expect(parsed.transformedSource[try! #require(parsed.commentsByID["u1"]).transformedHighlightRange] == span)

        // Editing to another unicode body round-trips too.
        let edited = try! #require(CriticMarkup.editComment(in: doc, id: "u1", newBody: "新しい本文 🎌"))
        #expect(CriticMarkup.preprocess(edited).commentsByID["u1"]?.body == "新しい本文 🎌")
    }

    /// I1/I2/I4/I6/I9: a random document under a random op sequence keeps every
    /// invariant after every op — no crash, idempotent strip, well-formed active
    /// set, and each successful wrap preserves all prior comments (B4).
    @Test("Property: random add/edit/delete sequences preserve all invariants")
    func opSequenceFuzz() {
        for seed in UInt64(0) ..< 250 {
            var rng = SeededRNG(seed: seed)
            var doc = Adversarial.randomMarkdown(using: &rng)
            for step in 0 ..< 8 {
                let parsed = assertCommentInvariants(doc, Ctx("seed \(seed) step \(step)"))
                switch rng.next() % 3 {
                case 0: // add: comment a random span of the transformed source
                    let t = parsed.transformedSource
                    let chars = Array(t)
                    guard chars.count > 1 else { break }
                    let lo = Int(rng.next() % UInt64(chars.count - 1))
                    let hi = min(chars.count, lo + 1 + Int(rng.next() % 10))
                    let tRange = t.index(t.startIndex, offsetBy: lo) ..< t.index(t.startIndex, offsetBy: hi)
                    guard let rawR = parsed.rawRange(forTransformed: tRange) else { break }
                    let before = Set(parsed.comments.map(\.id))
                    if let next = CriticMarkup.wrapComment(in: parsed.rawSource, range: rawR, body: "b\(seed)\(step)") {
                        let after = Set(CriticMarkup.preprocess(next).comments.map(\.id))
                        // B4: every prior comment survives; the set grows by one.
                        #expect(before.isSubset(of: after), "seed \(seed) step \(step): a prior comment was lost")
                        #expect(after.count == before.count + 1, "seed \(seed) step \(step): add didn't add exactly one")
                        doc = next
                    }
                case 1: // edit a random existing comment
                    if let id = parsed.comments.randomElement(using: &rng)?.id,
                       let next = CriticMarkup.editComment(in: doc, id: id, newBody: "e\(seed)\(step)") {
                        #expect(CriticMarkup.preprocess(next).commentsByID[id]?.body == "e\(seed)\(step)")
                        doc = next
                    }
                default: // delete a random existing comment
                    if let id = parsed.comments.randomElement(using: &rng)?.id {
                        let next = CriticMarkup.deleteComment(in: doc, id: id)
                        #expect(CriticMarkup.preprocess(next).commentsByID[id] == nil)
                        doc = next
                    }
                }
            }
        }
    }
}
