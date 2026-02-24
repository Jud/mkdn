import Foundation
import Testing
@testable import mkdnLib

@Suite("Markdown File Filter")
struct MarkdownFileFilterTests {
    @Test(".md extension accepted")
    @MainActor func acceptsMd() {
        let url = URL(fileURLWithPath: "/tmp/readme.md")
        #expect(FileOpenCoordinator.isMarkdownURL(url))
    }

    @Test(".markdown extension accepted")
    @MainActor func acceptsMarkdown() {
        let url = URL(fileURLWithPath: "/tmp/readme.markdown")
        #expect(FileOpenCoordinator.isMarkdownURL(url))
    }

    @Test(".txt extension rejected")
    @MainActor func rejectsTxt() {
        let url = URL(fileURLWithPath: "/tmp/readme.txt")
        #expect(!FileOpenCoordinator.isMarkdownURL(url))
    }

    @Test(".html extension rejected")
    @MainActor func rejectsHtml() {
        let url = URL(fileURLWithPath: "/tmp/readme.html")
        #expect(!FileOpenCoordinator.isMarkdownURL(url))
    }

    @Test(".rst extension rejected")
    @MainActor func rejectsRst() {
        let url = URL(fileURLWithPath: "/tmp/readme.rst")
        #expect(!FileOpenCoordinator.isMarkdownURL(url))
    }

    @Test("Case-insensitive: .MD accepted")
    @MainActor func acceptsUppercaseMD() {
        let url = URL(fileURLWithPath: "/tmp/README.MD")
        #expect(FileOpenCoordinator.isMarkdownURL(url))
    }

    @Test("Case-insensitive: .Markdown accepted")
    @MainActor func acceptsMixedCaseMarkdown() {
        let url = URL(fileURLWithPath: "/tmp/README.Markdown")
        #expect(FileOpenCoordinator.isMarkdownURL(url))
    }
}
