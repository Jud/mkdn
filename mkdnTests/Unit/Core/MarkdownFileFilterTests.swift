import Foundation
import Testing
@testable import mkdnLib

@Suite("Markdown File Filter")
struct MarkdownFileFilterTests {
    @Test(".md extension accepted")
    func acceptsMd() {
        let url = URL(fileURLWithPath: "/tmp/readme.md")
        #expect(url.isMarkdownFile)
    }

    @Test(".markdown extension accepted")
    func acceptsMarkdown() {
        let url = URL(fileURLWithPath: "/tmp/readme.markdown")
        #expect(url.isMarkdownFile)
    }

    @Test(".txt extension rejected")
    func rejectsTxt() {
        let url = URL(fileURLWithPath: "/tmp/readme.txt")
        #expect(!url.isMarkdownFile)
    }

    @Test(".html extension rejected")
    func rejectsHtml() {
        let url = URL(fileURLWithPath: "/tmp/readme.html")
        #expect(!url.isMarkdownFile)
    }

    @Test(".rst extension rejected")
    func rejectsRst() {
        let url = URL(fileURLWithPath: "/tmp/readme.rst")
        #expect(!url.isMarkdownFile)
    }

    @Test("Case-insensitive: .MD accepted")
    func acceptsUppercaseMD() {
        let url = URL(fileURLWithPath: "/tmp/README.MD")
        #expect(url.isMarkdownFile)
    }

    @Test("Case-insensitive: .Markdown accepted")
    func acceptsMixedCaseMarkdown() {
        let url = URL(fileURLWithPath: "/tmp/README.Markdown")
        #expect(url.isMarkdownFile)
    }
}
