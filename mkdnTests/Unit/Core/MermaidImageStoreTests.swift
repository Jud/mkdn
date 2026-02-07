import AppKit
import Testing

@testable import mkdnLib

@Suite("MermaidImageStore")
struct MermaidImageStoreTests {
    private static func makeImage(width: Int = 1, height: Int = 1) -> NSImage {
        NSImage(size: NSSize(width: width, height: height))
    }

    @Test("Returns nil for cache miss")
    @MainActor func cacheMiss() {
        let store = MermaidImageStore(capacity: 5)
        let result = store.get("graph TD\n    A --> B", theme: .solarizedDark)

        #expect(result == nil)
    }

    @Test("Stores and retrieves an image")
    @MainActor func basicStoreAndGet() {
        let store = MermaidImageStore(capacity: 5)
        let image = Self.makeImage()
        let code = "graph TD\n    A --> B"

        store.store(code, image: image, theme: .solarizedDark)
        let result = store.get(code, theme: .solarizedDark)

        #expect(result != nil)
        #expect(result === image)
    }

    @Test("Same code returns same cached image instance")
    @MainActor func cacheHitReturnsSameInstance() {
        let store = MermaidImageStore(capacity: 5)
        let image = Self.makeImage()
        let code = "graph TD\n    A --> B"

        store.store(code, image: image, theme: .solarizedDark)

        let first = store.get(code, theme: .solarizedDark)
        let second = store.get(code, theme: .solarizedDark)

        #expect(first === image)
        #expect(second === image)
        #expect(first === second)
    }

    @Test("Different code produces cache miss")
    @MainActor func differentCodeMisses() {
        let store = MermaidImageStore(capacity: 5)
        let image = Self.makeImage()

        store.store("graph TD\n    A --> B", image: image, theme: .solarizedDark)
        let result = store.get("graph TD\n    A --> C", theme: .solarizedDark)

        #expect(result == nil)
    }

    @Test("Overwrites existing entry with same code and theme")
    @MainActor func overwriteExistingEntry() {
        let store = MermaidImageStore(capacity: 5)
        let code = "graph TD\n    A --> B"
        let imageA = Self.makeImage()
        let imageB = Self.makeImage(width: 2, height: 2)

        store.store(code, image: imageA, theme: .solarizedDark)
        store.store(code, image: imageB, theme: .solarizedDark)

        let result = store.get(code, theme: .solarizedDark)

        #expect(result === imageB)
        #expect(store.count == 1)
    }

    @Test("Evicts least-recently-used entry when at capacity")
    @MainActor func lruEviction() {
        let store = MermaidImageStore(capacity: 3)
        let codeA = "graph TD\n    A"
        let codeB = "graph TD\n    B"
        let codeC = "graph TD\n    C"
        let codeD = "graph TD\n    D"

        store.store(codeA, image: Self.makeImage(), theme: .solarizedDark)
        store.store(codeB, image: Self.makeImage(), theme: .solarizedDark)
        store.store(codeC, image: Self.makeImage(), theme: .solarizedDark)

        store.store(codeD, image: Self.makeImage(), theme: .solarizedDark)

        #expect(store.get(codeA, theme: .solarizedDark) == nil)
        #expect(store.get(codeB, theme: .solarizedDark) != nil)
        #expect(store.get(codeC, theme: .solarizedDark) != nil)
        #expect(store.get(codeD, theme: .solarizedDark) != nil)
        #expect(store.count == 3)
    }

    @Test("Accessing an entry promotes it and prevents eviction")
    @MainActor func accessPromotesEntry() {
        let store = MermaidImageStore(capacity: 3)
        let codeA = "graph TD\n    A"
        let codeB = "graph TD\n    B"
        let codeC = "graph TD\n    C"
        let codeD = "graph TD\n    D"

        store.store(codeA, image: Self.makeImage(), theme: .solarizedDark)
        store.store(codeB, image: Self.makeImage(), theme: .solarizedDark)
        store.store(codeC, image: Self.makeImage(), theme: .solarizedDark)

        _ = store.get(codeA, theme: .solarizedDark)

        store.store(codeD, image: Self.makeImage(), theme: .solarizedDark)

        #expect(store.get(codeA, theme: .solarizedDark) != nil)
        #expect(store.get(codeB, theme: .solarizedDark) == nil)
        #expect(store.get(codeC, theme: .solarizedDark) != nil)
        #expect(store.get(codeD, theme: .solarizedDark) != nil)
    }

    @Test("removeAll clears cache")
    @MainActor func removeAllClearsCache() {
        let store = MermaidImageStore(capacity: 5)
        store.store("graph TD\n    A", image: Self.makeImage(), theme: .solarizedDark)
        store.store("graph TD\n    B", image: Self.makeImage(), theme: .solarizedDark)
        store.store("graph TD\n    C", image: Self.makeImage(), theme: .solarizedDark)

        store.removeAll()

        #expect(store.isEmpty)
        #expect(store.get("graph TD\n    A", theme: .solarizedDark) == nil)
        #expect(store.get("graph TD\n    B", theme: .solarizedDark) == nil)
        #expect(store.get("graph TD\n    C", theme: .solarizedDark) == nil)
    }

    @Test("Count reflects current number of entries")
    @MainActor func countTracksEntries() {
        let store = MermaidImageStore(capacity: 5)

        #expect(store.isEmpty)

        store.store("graph TD\n    A", image: Self.makeImage(), theme: .solarizedDark)
        #expect(store.count == 1)

        store.store("graph TD\n    B", image: Self.makeImage(), theme: .solarizedDark)
        #expect(store.count == 2)

        store.removeAll()
        #expect(store.isEmpty)
    }

    @Test("Same code with different themes stored as separate entries")
    @MainActor func themeAwareCaching() {
        let store = MermaidImageStore(capacity: 10)
        let code = "graph TD\n    A --> B"
        let darkImage = Self.makeImage(width: 10, height: 10)
        let lightImage = Self.makeImage(width: 20, height: 20)

        store.store(code, image: darkImage, theme: .solarizedDark)
        store.store(code, image: lightImage, theme: .solarizedLight)

        #expect(store.get(code, theme: .solarizedDark) === darkImage)
        #expect(store.get(code, theme: .solarizedLight) === lightImage)
        #expect(store.count == 2)
    }

    @Test("Theme miss returns nil even when other theme is cached")
    @MainActor func themeMissReturnsNil() {
        let store = MermaidImageStore(capacity: 5)
        let code = "graph TD\n    A --> B"

        store.store(code, image: Self.makeImage(), theme: .solarizedDark)

        #expect(store.get(code, theme: .solarizedLight) == nil)
    }
}
