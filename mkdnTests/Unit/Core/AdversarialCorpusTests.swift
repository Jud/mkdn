import Foundation
import Testing
@testable import mkdnLib

/// Enumerated hostile inputs (cats A/B/C/D) plus seeded fuzz, asserting the
/// no-crash / no-residue / well-formed-active-set invariants (I1, I2, I9). These
/// are characterization-level: they prove `preprocess` survives garbage and
/// leaves no recognized residue. Targeted bug tests (B1–B4) live in their own
/// suites.
@Suite("Comment adversarial corpus")
struct AdversarialCorpusTests {
    private static func st(_ id: String) -> String { CriticMarkup.anchorToken(id: id, edge: .start) }
    private static func en(_ id: String) -> String { CriticMarkup.anchorToken(id: id, edge: .end) }
    private static func sidecar(_ entries: [CommentSidecar.Entry]) -> String {
        "\n\n" + CommentSidecar.encode(entries)
    }

    /// (name, raw) hostile documents fed to `preprocess`.
    static var corpus: [(name: String, raw: String)] {
        let s = st, e = en
        return [
            // A — malformed / pathological anchors
            ("anchor-missing-end", "foo \(s("a"))bar baz"),
            ("anchor-missing-start", "foo bar\(e("a")) baz"),
            ("anchor-start-after-end", "foo \(e("a"))bar\(s("a")) baz" + sidecar([.init(id: "a", body: "x")])),
            ("anchor-empty-span", "foo \(s("a"))\(e("a")) bar" + sidecar([.init(id: "a", body: "x")])),
            ("anchor-crossing", "\(s("a"))A \(s("b"))B\(e("a")) C\(e("b"))"
                + sidecar([.init(id: "a", body: "x"), .init(id: "b", body: "y")])),
            ("anchor-nested", "\(s("a"))A \(s("b"))B\(e("b")) C\(e("a"))"
                + sidecar([.init(id: "a", body: "x"), .init(id: "b", body: "y")])),
            ("anchor-dup-start", "\(s("a"))x\(s("a"))y\(e("a"))z" + sidecar([.init(id: "a", body: "x")])),
            ("anchor-malformed-no-id", "foo <mkdn-comment edge=\"start\"/>bar"),
            ("anchor-malformed-gt-inside", "foo <mkdn-comment id=\"x>y\" edge=\"start\"/>bar"),
            ("anchor-in-code-fence", "```\n\(s("a"))code\(e("a"))\n```" + sidecar([.init(id: "a", body: "x")])),
            ("anchor-at-sol", "\(s("a"))# Heading\(e("a"))\n\ntext" + sidecar([.init(id: "a", body: "x")])),
            ("anchor-literal-typed", "I typed <mkdn-comment id=\"x\" edge=\"start\"/> in prose"),
            ("anchor-many", String(repeating: "\(s("a"))x\(e("a")) ", count: 200)),

            // B — sidecar pathologies
            ("sidecar-absent", "just plain text\n\nwith blocks"),
            ("sidecar-malformed-json", "doc\n\n<!--mkdn-comments\n{not valid json\n-->"),
            ("sidecar-empty", "doc" + sidecar([])),
            ("sidecar-orphan-entry", "doc with no anchors" + sidecar([.init(id: "z", body: "orphan")])),
            ("sidecar-dup-ids", "\(s("a"))x\(e("a"))"
                + sidecar([.init(id: "a", body: "one"), .init(id: "a", body: "two")])),
            ("sidecar-unknown-keys", "doc\n\n<!--mkdn-comments\n{\"v\":1,\"extra\":true,\"comments\":[]}\n-->"),
            ("sidecar-body-hostile", "\(s("a"))x\(e("a"))"
                + sidecar([.init(id: "a", body: "has --> and -- and <!--mkdn-comments and \n newline 😀")])),
            ("sidecar-truncated", "doc\n\n<!--mkdn-comments\n{\"v\":1,\"comments\":["),

            // C — unicode / encoding
            ("unicode-emoji", CommentFixture.doc("wave 😀🎉 there", comment: "😀🎉")),
            ("unicode-combining", CommentFixture.doc("cafe\u{0301} time", comment: "cafe\u{0301}")),
            ("unicode-rtl", CommentFixture.doc("x \u{202E}rtl\u{202C} y", comment: "rtl")),
            ("unicode-crlf", "line one\r\nline two\r\n\r\nlast"),
            ("unicode-nul", "before\u{0000}after"),
            ("unicode-bom", "\u{FEFF}# Title\n\nbody"),

            // D — structural
            ("empty", ""),
            ("whitespace-only", "   \n\n\t  \n"),
            ("only-anchors", "\(s("a"))\(e("a"))"),
            ("only-sidecar", CommentSidecar.encode([.init(id: "a", body: "x")])),
            ("comment-over-whole-doc", CommentFixture.doc("entire body here", comment: "entire body here")),
            ("comment-over-link", CommentFixture.doc("see [docs](https://x.com) now", comment: "[docs](https://x.com)")),
            ("comment-over-code", CommentFixture.doc("run `swift build` ok", comment: "`swift build`")),
        ]
    }

    @Test("Every hostile corpus document parses without crash or residue", arguments: corpus)
    func corpusSurvives(name: String, raw: String) {
        assertCommentInvariants(raw, Ctx(name))
    }

    @Test("Seeded random documents parse without crash or residue")
    func seededFuzz() {
        for seed in UInt64(0) ..< 400 {
            var rng = SeededRNG(seed: seed)
            let doc = Adversarial.randomMarkdown(using: &rng)
            assertCommentInvariants(doc, Ctx("seed \(seed)"))
        }
    }
}
