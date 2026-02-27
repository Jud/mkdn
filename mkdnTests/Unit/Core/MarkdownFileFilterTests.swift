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

    // MARK: - isTextFile

    @Test("Markdown files are text files")
    func markdownIsTextFile() {
        let url = URL(fileURLWithPath: "/tmp/readme.md")
        #expect(url.isTextFile)
    }

    @Test("Source code files are text files")
    func sourceCodeIsTextFile() {
        let swift = URL(fileURLWithPath: "/tmp/main.swift")
        let json = URL(fileURLWithPath: "/tmp/data.json")
        let sh = URL(fileURLWithPath: "/tmp/script.sh")

        #expect(swift.isTextFile)
        #expect(json.isTextFile)
        #expect(sh.isTextFile)
    }

    @Test("Plain text files are text files")
    func plainTextIsTextFile() {
        let url = URL(fileURLWithPath: "/tmp/notes.txt")
        #expect(url.isTextFile)
    }

    @Test("Unrecognized extensions are not text files")
    func unrecognizedNotTextFile() {
        let png = URL(fileURLWithPath: "/tmp/image.png")
        let pdf = URL(fileURLWithPath: "/tmp/report.pdf")
        let rst = URL(fileURLWithPath: "/tmp/readme.rst")

        #expect(!png.isTextFile)
        #expect(!pdf.isTextFile)
        #expect(!rst.isTextFile)
    }
}
