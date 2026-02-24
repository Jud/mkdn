import Foundation
import Testing
@testable import mkdnLib

@Suite("LinkNavigationHandler")
struct LinkNavigationHandlerTests {
    private let documentURL = URL(fileURLWithPath: "/Users/test/docs/readme.md")

    // MARK: - External URL Classification

    @Test("Classifies http URL as external")
    func classifiesHttpAsExternal() throws {
        let url = try #require(URL(string: "https://example.com/page"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        #expect(result == .external(url))
    }

    @Test("Classifies http (no TLS) URL as external")
    func classifiesHttpNoTLSAsExternal() throws {
        let url = try #require(URL(string: "http://example.com"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        #expect(result == .external(url))
    }

    @Test("Classifies mailto URL as external")
    func classifiesMailtoAsExternal() throws {
        let url = try #require(URL(string: "mailto:user@example.com"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        #expect(result == .external(url))
    }

    @Test("Classifies tel URL as external")
    func classifiesTelAsExternal() throws {
        let url = try #require(URL(string: "tel:+1234567890"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        #expect(result == .external(url))
    }

    @Test("Classifies unknown scheme as external")
    func classifiesUnknownSchemeAsExternal() throws {
        let url = try #require(URL(string: "slack://channel/general"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        #expect(result == .external(url))
    }

    // MARK: - Local Markdown Classification

    @Test("Classifies relative .md path as local markdown")
    func classifiesRelativeMdAsLocalMarkdown() throws {
        let url = try #require(URL(string: "other.md"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/test/docs/other.md")
        #expect(result == .localMarkdown(expected))
    }

    @Test("Classifies relative .markdown path as local markdown")
    func classifiesRelativeMarkdownAsLocalMarkdown() throws {
        let url = try #require(URL(string: "notes.markdown"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/test/docs/notes.markdown")
        #expect(result == .localMarkdown(expected))
    }

    @Test("Classifies subdirectory .md path as local markdown")
    func classifiesSubdirMdAsLocalMarkdown() throws {
        let url = try #require(URL(string: "subdir/file.md"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/test/docs/subdir/file.md")
        #expect(result == .localMarkdown(expected))
    }

    @Test("Classifies file:// .md URL as local markdown")
    func classifiesFileSchemeMdAsLocalMarkdown() throws {
        let url = try #require(URL(string: "file:///absolute/path/doc.md"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/absolute/path/doc.md")
        #expect(result == .localMarkdown(expected))
    }

    // MARK: - Other Local File Classification

    @Test("Classifies relative .txt path as other local file")
    func classifiesRelativeTxtAsOtherLocal() throws {
        let url = try #require(URL(string: "notes.txt"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/test/docs/notes.txt")
        #expect(result == .otherLocalFile(expected))
    }

    @Test("Classifies relative .pdf path as other local file")
    func classifiesRelativePdfAsOtherLocal() throws {
        let url = try #require(URL(string: "document.pdf"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/test/docs/document.pdf")
        #expect(result == .otherLocalFile(expected))
    }

    // MARK: - Relative Path Resolution

    @Test("Resolves parent directory traversal")
    func resolvesParentDirectoryTraversal() throws {
        let url = try #require(URL(string: "../sibling/file.md"))
        let result = LinkNavigationHandler.resolveRelativeURL(url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/test/sibling/file.md")
        #expect(result == expected)
    }

    @Test("Resolves dot-slash prefix")
    func resolvesDotSlashPrefix() throws {
        let url = try #require(URL(string: "./other.md"))
        let result = LinkNavigationHandler.resolveRelativeURL(url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/test/docs/other.md")
        #expect(result == expected)
    }

    @Test("Returns original URL when no document URL provided")
    func returnsOriginalWhenNoDocument() throws {
        let url = try #require(URL(string: "other.md"))
        let result = LinkNavigationHandler.resolveRelativeURL(url, relativeTo: nil)
        #expect(result == url)
    }

    @Test("Returns document URL for empty path (anchor-only)")
    func returnsDocumentURLForAnchorOnly() throws {
        let url = try #require(URL(string: "#heading"))
        let result = LinkNavigationHandler.resolveRelativeURL(url, relativeTo: documentURL)
        #expect(result == documentURL)
    }

    @Test("Classifies anchor-only link relative to current document")
    func classifiesAnchorOnlyAsLocalMarkdown() throws {
        let url = try #require(URL(string: "#heading"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        #expect(result == .localMarkdown(documentURL))
    }

    // MARK: - Edge Cases

    @Test("Handles deeply nested relative path")
    func handlesDeeplyNestedRelativePath() throws {
        let url = try #require(URL(string: "a/b/c/deep.md"))
        let result = LinkNavigationHandler.classify(url: url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/test/docs/a/b/c/deep.md")
        #expect(result == .localMarkdown(expected))
    }

    @Test("Handles multiple parent directory traversals")
    func handlesMultipleParentTraversals() throws {
        let url = try #require(URL(string: "../../other.md"))
        let result = LinkNavigationHandler.resolveRelativeURL(url, relativeTo: documentURL)
        let expected = URL(fileURLWithPath: "/Users/other.md")
        #expect(result == expected)
    }
}
