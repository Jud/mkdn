import Foundation
import Testing
@testable import mkdnLib

// Shared support for the comment adversarial-hardening suites: a reproducible
// PRNG, random document / op generators, reusable invariant assertions, and an
// enumerated corpus of hostile inputs (named cases for CI clarity). See
// docs/features/markdown-comments/adversarial-hardening-plan.md.

/// SplitMix64 — a small, reproducible RNG so fuzz cases are deterministic and a
/// failing seed can be replayed.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum Adversarial {
    /// Fragments a random document is assembled from — a spread of block and
    /// inline constructs plus multi-byte/awkward scalars.
    static let fragments: [String] = [
        "The quick brown fox", "# Heading one", "## Sub heading",
        "- list item", "1. ordered item", "> a block quote",
        "`inline code`", "run `swift build` now", "[a link](https://example.com)",
        "**bold** and *italic* text", "~~struck~~ through", "plain paragraph text",
        "a line\nwith a soft break", "emoji 😀🎉 and flags 🇺🇸 here",
        "combining e\u{0301}\u{0301} marks", "RTL \u{202E}reversed\u{202C} text",
        "tab\tseparated\tvalues", "trailing spaces   ", "  leading spaces",
        "an ampersand & a < and a >", "a backslash \\ and a quote \"",
        "```\ncode fence\n```", "| a | b |\n| - | - |\n| 1 | 2 |",
        "zero\u{200B}width", "math $x^2$ inline", "<div>raw html</div>",
    ]

    /// Build a deterministic pseudo-random markdown document.
    static func randomMarkdown(using rng: inout SeededRNG, blocks: Int = 6) -> String {
        var parts: [String] = []
        for _ in 0 ..< blocks {
            parts.append(fragments.randomElement(using: &rng) ?? "text")
        }
        return parts.joined(separator: "\n\n")
    }

    /// A small set of substrings worth trying to comment in a generated doc.
    static func candidateSpans(in doc: String) -> [String] {
        ["quick", "brown fox", "swift build", "link", "bold", "item", "😀🎉",
         "reversed", "code", "x^2", "html", "a < and"]
            .filter { doc.contains($0) }
    }
}

// MARK: - Invariant assertions

/// I1/I2/I9: `preprocess` produces no recognized-marker residue (it is
/// idempotent on its own output) and every active comment is well-formed (has a
/// sidecar body source and a non-empty, in-bounds highlight). Returns the parsed
/// document for further assertions.
@discardableResult
func assertCommentInvariants(_ raw: String, _ ctx: Ctx = .init()) -> CriticMarkupDocument {
    let doc = CriticMarkup.preprocess(raw)

    // Idempotence: re-running over the stripped output changes nothing and finds
    // no comments — i.e. nothing recognized was left behind (narrowed I2).
    let again = CriticMarkup.preprocess(doc.transformedSource)
    #expect(again.transformedSource == doc.transformedSource, "preprocess not idempotent\(ctx)")
    #expect(again.comments.isEmpty, "residual comments after re-parse\(ctx)")

    // Each active comment's highlight is a non-empty in-bounds slice.
    for c in doc.comments {
        #expect(c.transformedHighlightRange.lowerBound < c.transformedHighlightRange.upperBound,
                "empty/inverted highlight for \(c.id)\(ctx)")
        #expect(c.transformedHighlightRange.upperBound <= doc.transformedSource.endIndex,
                "out-of-bounds highlight for \(c.id)\(ctx)")
    }
    // Ids are unique among active comments.
    #expect(Set(doc.comments.map(\.id)).count == doc.comments.count, "duplicate active ids\(ctx)")
    return doc
}

/// The active-comment id→body map, for set/algebra comparisons.
func activeComments(_ raw: String) -> [String: String] {
    Dictionary(CriticMarkup.preprocess(raw).comments.map { ($0.id, $0.body) },
               uniquingKeysWith: { a, _ in a })
}

/// A trailing label for assertion messages (e.g. the corpus case name or seed).
/// Named `Ctx`, not `Comment`, to avoid colliding with swift-testing's `Comment`.
struct Ctx: CustomStringConvertible {
    let text: String
    init() { text = "" }
    init(_ text: String) { self.text = " [\(text)]" }
    var description: String { text }
}
