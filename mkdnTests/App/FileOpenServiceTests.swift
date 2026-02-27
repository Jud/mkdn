import Foundation
import Testing
@testable import mkdnLib

@Suite("FileOpenService")
struct FileOpenServiceTests {
    @Test("pendingURLs starts empty")
    @MainActor func startsEmpty() {
        let service = FileOpenService()
        #expect(service.pendingURLs.isEmpty)
    }

    @Test("consumePendingURLs returns all URLs and clears the queue")
    @MainActor func consumeReturnsThenClears() {
        let service = FileOpenService()
        let first = URL(fileURLWithPath: "/tmp/a.md")
        let second = URL(fileURLWithPath: "/tmp/b.md")

        service.pendingURLs.append(first)
        service.pendingURLs.append(second)

        let consumed = service.consumePendingURLs()

        #expect(consumed == [first, second])
        #expect(service.pendingURLs.isEmpty)
    }

    @Test("consumePendingURLs on empty queue returns empty array")
    @MainActor func consumeEmptyReturnsEmpty() {
        let service = FileOpenService()

        let consumed = service.consumePendingURLs()

        #expect(consumed.isEmpty)
    }

    @Test("Warm launch with windows appends to pendingURLs")
    @MainActor func warmWithWindowsAppendsPending() {
        let service = FileOpenService()
        let url = URL(fileURLWithPath: "/tmp/test.md")

        service.handleOpenDocuments(
            urls: [url],
            didFinishLaunching: true,
            hasVisibleWindows: true
        )

        #expect(service.pendingURLs == [url])
    }

    @Test("Warm launch with no windows calls openFileWindow")
    @MainActor func warmNoWindowsCallsOpenFileWindow() {
        let service = FileOpenService()
        let url = URL(fileURLWithPath: "/tmp/test.md")
        var opened: [URL] = []
        service.openFileWindow = { opened.append($0) }

        service.handleOpenDocuments(
            urls: [url],
            didFinishLaunching: true,
            hasVisibleWindows: false
        )

        #expect(opened == [url])
        #expect(service.pendingURLs.isEmpty)
    }

    @Test("Cold launch calls reexecHandler")
    @MainActor func coldLaunchCallsReexecHandler() {
        let service = FileOpenService()
        let url = URL(fileURLWithPath: "/tmp/test.md")
        var reexecURLs: [URL] = []
        service.reexecHandler = { reexecURLs = $0 }

        service.handleOpenDocuments(
            urls: [url],
            didFinishLaunching: false,
            hasVisibleWindows: false
        )

        #expect(reexecURLs == [url])
    }

    @Test("Unrecognized file types are filtered out")
    @MainActor func unrecognizedFiltered() {
        let service = FileOpenService()
        let png = URL(fileURLWithPath: "/tmp/photo.png")
        let pdf = URL(fileURLWithPath: "/tmp/report.pdf")

        service.handleOpenDocuments(
            urls: [png, pdf],
            didFinishLaunching: true,
            hasVisibleWindows: true
        )

        #expect(service.pendingURLs.isEmpty)
    }

    @Test("Text files are accepted alongside markdown")
    @MainActor func textFilesAccepted() {
        let service = FileOpenService()
        let md = URL(fileURLWithPath: "/tmp/readme.md")
        let txt = URL(fileURLWithPath: "/tmp/notes.txt")
        let swift = URL(fileURLWithPath: "/tmp/main.swift")
        let html = URL(fileURLWithPath: "/tmp/index.html")

        service.handleOpenDocuments(
            urls: [md, txt, swift, html],
            didFinishLaunching: true,
            hasVisibleWindows: true
        )

        #expect(service.pendingURLs == [md, txt, swift, html])
    }

    @Test("Mixed URLs: only recognized text files are routed")
    @MainActor func mixedURLsOnlyTextFilesRouted() {
        let service = FileOpenService()
        let md = URL(fileURLWithPath: "/tmp/readme.md")
        let png = URL(fileURLWithPath: "/tmp/photo.png")
        let json = URL(fileURLWithPath: "/tmp/data.json")

        service.handleOpenDocuments(
            urls: [md, png, json],
            didFinishLaunching: true,
            hasVisibleWindows: true
        )

        #expect(service.pendingURLs == [md, json])
    }
}
