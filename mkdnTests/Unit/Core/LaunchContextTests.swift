import Foundation
import Testing
@testable import mkdnLib

@Suite("LaunchContext")
struct LaunchContextTests {
    @Test("fileURLs starts empty")
    func startsEmpty() {
        LaunchContext.fileURLs = []
        #expect(LaunchContext.fileURLs.isEmpty)
    }

    @Test("consumeURLs returns all URLs and clears them")
    func consumeURLsReturnsThenClears() {
        let urlA = URL(fileURLWithPath: "/tmp/a.md")
        let urlB = URL(fileURLWithPath: "/tmp/b.md")
        let urlC = URL(fileURLWithPath: "/tmp/c.md")

        LaunchContext.fileURLs = [urlA, urlB, urlC]

        let consumed = LaunchContext.consumeURLs()

        #expect(consumed == [urlA, urlB, urlC])
        #expect(LaunchContext.fileURLs.isEmpty)
    }

    @Test("consumeURLs on empty returns empty array")
    func consumeURLsEmptyReturnsEmpty() {
        LaunchContext.fileURLs = []

        let consumed = LaunchContext.consumeURLs()

        #expect(consumed.isEmpty)
        #expect(LaunchContext.fileURLs.isEmpty)
    }

    @Test("single URL round-trip")
    func singleURLRoundTrip() {
        let url = URL(fileURLWithPath: "/tmp/single.md")

        LaunchContext.fileURLs = [url]
        let consumed = LaunchContext.consumeURLs()

        #expect(consumed == [url])
        #expect(LaunchContext.fileURLs.isEmpty)
    }
}
