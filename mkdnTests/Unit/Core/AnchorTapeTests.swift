#if os(macOS)
    import AppKit
    import Testing
    @testable import mkdnLib

    @Suite("AnchorTape")
    @MainActor
    struct AnchorTapeTests {
    /// Builder NSRange for a normalized substring, via UTF-16 offsets.
    private func builderRange(of normalizedSubstring: String, in tape: AnchorTape) -> NSRange? {
        let ns = tape.text as NSString
        let r = ns.range(of: normalizedSubstring)
        guard r.location != NSNotFound else { return nil }
        return tape.builderRange(forNormalized: r.location ..< NSMaxRange(r))
    }

    // MARK: - Prose normalization

    @Test("Prose collapses whitespace runs and ASCII-case-folds")
    func proseNormalized() {
        let tape = AnchorTape.build(from: NSAttributedString(string: "Hello   World"))
        #expect(tape.text == "hello world")
    }

    @Test("A normalized span maps back to its verbatim builder range")
    func mapsNormalizedSpanToBuilder() throws {
        let source = "Hello   World"
        let tape = AnchorTape.build(from: NSAttributedString(string: source))
        let nsr = try #require(builderRange(of: "world", in: tape))
        #expect((source as NSString).substring(with: nsr) == "World")
    }

    @Test("A span covering a collapsed whitespace run includes the whole run")
    func spanCoversCollapsedWhitespace() throws {
        let source = "Hello   World"
        let tape = AnchorTape.build(from: NSAttributedString(string: source))
        let nsr = try #require(builderRange(of: "hello world", in: tape))
        #expect((source as NSString).substring(with: nsr) == source) // all 3 spaces included
    }

    // MARK: - Code is verbatim

    @Test("Fenced code is preserved verbatim (case + whitespace)")
    func fencedCodeVerbatim() {
        let indexed = IndexedBlock(index: 0, block: .codeBlock(language: "swift", code: "Let  X = 1"))
        let result = MarkdownTextStorageBuilder.build(blocks: [indexed], theme: .solarizedDark)
        let tape = AnchorTape.build(from: result.attributedString)
        #expect(tape.text.contains("Let  X = 1"))   // caps + double space kept
        #expect(!tape.text.contains("let  x = 1"))
    }

    @Test("Inline code is verbatim while surrounding prose is normalized")
    func inlineCodeVerbatim() {
        let blocks = MarkdownRenderer.render(text: "Use `MixedCase` Now", theme: .solarizedDark)
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: .solarizedDark)
        let tape = AnchorTape.build(from: result.attributedString)
        #expect(tape.text.contains("MixedCase"))   // inline code verbatim
        #expect(!tape.text.contains("mixedcase"))
        #expect(tape.text.contains("use "))         // prose folded
        #expect(tape.text.contains(" now"))
    }

    @Test("Attachment runs are excluded from the tape")
    func attachmentsExcluded() {
        let s = NSMutableAttributedString(string: "before ")
        s.append(NSAttributedString(attachment: NSTextAttachment()))
        s.append(NSAttributedString(string: " after"))
        let tape = AnchorTape.build(from: s)
        #expect(!tape.text.contains("\u{FFFC}"))
        #expect(tape.text == "before after") // whitespace around the attachment collapses
    }

    // MARK: - Edges

    @Test("Empty input yields empty tape and no mappable range")
    func emptyInput() {
        let tape = AnchorTape.build(from: NSAttributedString())
        #expect(tape.text.isEmpty)
        #expect(tape.builderRange(forNormalized: 0 ..< 1) == nil)
    }

    @Test("Empty and out-of-bounds normalized ranges map to nil")
    func rejectsDegenerateRanges() {
        let tape = AnchorTape.build(from: NSAttributedString(string: "abc"))
        #expect(tape.builderRange(forNormalized: 1 ..< 1) == nil)   // empty
        #expect(tape.builderRange(forNormalized: 2 ..< 9) == nil)   // upper out of bounds
        #expect(tape.builderRange(forNormalized: 0 ..< 3) == NSRange(location: 0, length: 3))
    }
}
#endif
