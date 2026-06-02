import Foundation
import Testing
@testable import mkdnLib

@Suite("CriticMarkup preprocessor")
struct CriticMarkupTests {
    // MARK: - Basic transform

    @Test("Strips a highlight+comment pair, keeping highlight text")
    func basicPair() {
        let doc = CriticMarkup.preprocess("foo {==bar==}{>>note<<} baz")

        #expect(doc.transformedSource == "foo bar baz")
        #expect(doc.comments.count == 1)
        let comment = doc.comments[0]
        #expect(comment.id == "c1")
        #expect(comment.body == "note")
        #expect(doc.rawSource[comment.rawHighlightRange] == "bar")
        #expect(doc.rawSource[comment.rawBodyRange] == "note")
        #expect(doc.rawSource[comment.rawFullRange] == "{==bar==}{>>note<<}")
        #expect(doc.transformedSource[comment.transformedHighlightRange] == "bar")
    }

    @Test("Highlight inner markdown is preserved for parsing")
    func highlightContainsInlineStyle() {
        let doc = CriticMarkup.preprocess("a {==**bold** x==}{>>c<<} b")
        #expect(doc.transformedSource == "a **bold** x b")
        #expect(doc.rawSource[doc.comments[0].rawHighlightRange] == "**bold** x")
    }

    @Test("Handles multiple adjacent comments with stable ids")
    func multipleComments() {
        let doc = CriticMarkup.preprocess("{==A==}{>>1<<}{==B==}{>>2<<}")
        #expect(doc.transformedSource == "AB")
        #expect(doc.comments.map(\.id) == ["c1", "c2"])
        #expect(doc.comments.map(\.body) == ["1", "2"])
    }

    // MARK: - Robustness (FR-2)

    @Test("Orphan comment with no preceding highlight is left literal")
    func orphanComment() {
        let doc = CriticMarkup.preprocess("text {>>dangling<<} more")
        #expect(doc.transformedSource == "text {>>dangling<<} more")
        #expect(doc.comments.isEmpty)
    }

    @Test("Highlight with no following comment is left literal")
    func orphanHighlight() {
        let doc = CriticMarkup.preprocess("text {==no comment==} more")
        #expect(doc.transformedSource == "text {==no comment==} more")
        #expect(doc.comments.isEmpty)
    }

    @Test("Unterminated highlight is left literal")
    func unterminated() {
        let doc = CriticMarkup.preprocess("text {==never closes")
        #expect(doc.transformedSource == "text {==never closes")
        #expect(doc.comments.isEmpty)
    }

    @Test("Empty highlight produces no comment")
    func emptyHighlight() {
        let doc = CriticMarkup.preprocess("a {====}{>>c<<} b")
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource == "a {====}{>>c<<} b")
    }

    @Test("Braces inside the comment body are retained verbatim")
    func bracesInBody() {
        let doc = CriticMarkup.preprocess("{==x==}{>>a {b} and ==} sign<<}")
        #expect(doc.comments.count == 1)
        #expect(doc.comments[0].body == "a {b} and ==} sign")
        #expect(doc.transformedSource == "x")
    }

    // MARK: - Code-region protection (FR-2a)

    @Test("Does not transform CriticMarkup inside a fenced code block")
    func fencedCodeProtected() {
        let source = """
        before

        ```
        let x = {==y==}{>>note<<}
        ```

        after
        """
        let doc = CriticMarkup.preprocess(source)
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource.contains("{==y==}{>>note<<}"))
    }

    @Test("Does not transform CriticMarkup inside a tilde-fenced code block")
    func tildeFencedCodeProtected() {
        let source = """
        before

        ~~~
        let x = {==y==}{>>note<<}
        ~~~

        after
        """
        let doc = CriticMarkup.preprocess(source)
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource.contains("{==y==}{>>note<<}"))
    }

    @Test("Does not transform CriticMarkup inside an inline code span")
    func inlineCodeProtected() {
        let doc = CriticMarkup.preprocess("use `{==y==}{>>n<<}` literally")
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource == "use `{==y==}{>>n<<}` literally")
    }

    @Test("Does not transform CriticMarkup inside an indented code block")
    func indentedCodeProtected() {
        let source = """
        paragraph

            let x = {==y==}{>>n<<}

        end
        """
        let doc = CriticMarkup.preprocess(source)
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource.contains("{==y==}{>>n<<}"))
    }

    @Test("Does not transform CriticMarkup inside an HTML block")
    func htmlBlockProtected() {
        let source = """
        <div>
        {==y==}{>>note<<}
        </div>
        """
        let doc = CriticMarkup.preprocess(source)
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource.contains("{==y==}{>>note<<}"))
    }

    @Test("Does not transform CriticMarkup inside a link destination")
    func linkDestinationProtected() {
        let doc = CriticMarkup.preprocess("see [the docs](https://a/{==p==}{>>c<<}) here")
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource.contains("{==p==}{>>c<<}"))
    }

    @Test("Does not transform CriticMarkup inside a link reference definition")
    func referenceDefinitionProtected() {
        let source = """
        See [the docs][id].

        [id]: https://example.com/{==p==}{>>c<<}
        """
        let doc = CriticMarkup.preprocess(source)
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource.contains("{==p==}{>>c<<}"))
    }

    @Test("Does not transform CriticMarkup inside a tab-indented code block")
    func tabIndentedCodeProtected() {
        let source = "paragraph\n\n\tlet x = {==y==}{>>n<<}\n\nend"
        let doc = CriticMarkup.preprocess(source)
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource.contains("{==y==}{>>n<<}"))
    }

    @Test("Adversarial opener spam terminates and leaves source intact")
    func adversarialOpeners() {
        // Many "{==" with no terminators must not hang or crash.
        let source = String(repeating: "{==", count: 5000)
        let doc = CriticMarkup.preprocess(source)
        #expect(doc.comments.isEmpty)
        #expect(doc.transformedSource == source)
    }

    @Test("Transforms a real comment even when an unrelated code block exists")
    func mixedCodeAndComment() {
        let source = """
        ```
        code {==x==}{>>ignored<<}
        ```

        prose {==real==}{>>kept<<} end
        """
        let doc = CriticMarkup.preprocess(source)
        #expect(doc.comments.count == 1)
        #expect(doc.comments[0].body == "kept")
        #expect(doc.transformedSource.contains("prose real end"))
        #expect(doc.transformedSource.contains("{==x==}{>>ignored<<}"))
    }

    // MARK: - Transformed → raw mapping

    @Test("Maps a highlight's transformed range back to the raw highlight")
    func mapsHighlightRange() {
        let doc = CriticMarkup.preprocess("foo {==bar==}{>>c<<} baz")
        let barRange = try! #require(doc.transformedSource.range(of: "bar"))
        let raw = try! #require(doc.rawRange(forTransformed: barRange))
        #expect(raw == doc.comments[0].rawHighlightRange)
        #expect(doc.rawSource[raw] == "bar")
    }

    @Test("Maps a sub-range within preserved text")
    func mapsSubRange() {
        let doc = CriticMarkup.preprocess("hello {==world==}{>>c<<}")
        let ell = try! #require(doc.transformedSource.range(of: "ell"))
        let raw = try! #require(doc.rawRange(forTransformed: ell))
        #expect(doc.rawSource[raw] == "ell")
    }

    @Test("Rejects a range that crosses a comment boundary")
    func rejectsCrossSegmentRange() {
        let doc = CriticMarkup.preprocess("foo {==bar==}{>>c<<} baz")
        // "o ba" runs from the leading text into the highlight — non-contiguous in raw.
        let crossing = try! #require(doc.transformedSource.range(of: "o ba"))
        #expect(doc.rawRange(forTransformed: crossing) == nil)
    }

    @Test("Rejects an empty transformed range")
    func rejectsEmptyRange() {
        let doc = CriticMarkup.preprocess("plain text")
        let idx = doc.transformedSource.startIndex
        #expect(doc.rawRange(forTransformed: idx ..< idx) == nil)
    }

    @Test("No CriticMarkup leaves the source untouched")
    func noMarkup() {
        let doc = CriticMarkup.preprocess("# Heading\n\nA paragraph with no comments.")
        #expect(doc.transformedSource == doc.rawSource)
        #expect(doc.comments.isEmpty)
    }
}
