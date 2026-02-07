import Testing

@testable import mkdnLib

@Suite("MermaidCache")
struct MermaidCacheTests {
    @Test("Returns nil for cache miss")
    func cacheMiss() {
        var cache = MermaidCache(capacity: 5)
        let result = cache.get(42)

        #expect(result == nil)
    }

    @Test("Stores and retrieves a value")
    func basicGetSet() {
        var cache = MermaidCache(capacity: 5)
        cache.set(1, value: "<svg>flowchart</svg>")

        let result = cache.get(1)

        #expect(result == "<svg>flowchart</svg>")
    }

    @Test("Overwrites existing entry with same key")
    func overwriteExistingKey() {
        var cache = MermaidCache(capacity: 5)
        cache.set(1, value: "old")
        cache.set(1, value: "new")

        #expect(cache.get(1) == "new")
        #expect(cache.count == 1)
    }

    @Test("Evicts least-recently-used entry when at capacity")
    func lruEviction() {
        var cache = MermaidCache(capacity: 3)
        cache.set(1, value: "a")
        cache.set(2, value: "b")
        cache.set(3, value: "c")

        cache.set(4, value: "d")

        #expect(cache.get(1) == nil)
        #expect(cache.get(2) == "b")
        #expect(cache.get(3) == "c")
        #expect(cache.get(4) == "d")
        #expect(cache.count == 3)
    }

    @Test("Accessing an entry promotes it and prevents eviction")
    func accessPromotesEntry() {
        var cache = MermaidCache(capacity: 3)
        cache.set(1, value: "a")
        cache.set(2, value: "b")
        cache.set(3, value: "c")

        _ = cache.get(1)

        cache.set(4, value: "d")

        #expect(cache.get(1) == "a")
        #expect(cache.get(2) == nil)
        #expect(cache.get(3) == "c")
        #expect(cache.get(4) == "d")
    }

    @Test("removeAll clears all entries")
    func removeAll() {
        var cache = MermaidCache(capacity: 5)
        cache.set(1, value: "a")
        cache.set(2, value: "b")
        cache.set(3, value: "c")

        cache.removeAll()

        #expect(cache.isEmpty)
        #expect(cache.get(1) == nil)
        #expect(cache.get(2) == nil)
        #expect(cache.get(3) == nil)
    }

    @Test("Count reflects current number of entries")
    func countTracksEntries() {
        var cache = MermaidCache(capacity: 5)

        #expect(cache.isEmpty)

        cache.set(1, value: "a")
        #expect(cache.count == 1)

        cache.set(2, value: "b")
        #expect(cache.count == 2)

        cache.removeAll()
        #expect(cache.isEmpty)
    }

    @Test("DJB2 hash produces consistent results for same input")
    func stableHashConsistency() {
        let input = "graph TD\n    A --> B"
        let hash1 = mermaidStableHash(input)
        let hash2 = mermaidStableHash(input)
        let hash3 = mermaidStableHash(input)

        #expect(hash1 == hash2)
        #expect(hash2 == hash3)
    }

    @Test("DJB2 hash produces different results for different inputs")
    func stableHashDistinctness() {
        let hash1 = mermaidStableHash("graph TD\n    A --> B")
        let hash2 = mermaidStableHash("graph TD\n    A --> C")

        #expect(hash1 != hash2)
    }

    @Test("Uses default capacity of 50")
    func defaultCapacity() {
        var cache = MermaidCache()

        for i: UInt64 in 0 ..< 50 {
            cache.set(i, value: "value-\(i)")
        }

        #expect(cache.count == 50)

        cache.set(99, value: "overflow")

        #expect(cache.count == 50)
        #expect(cache.get(0) == nil)
        #expect(cache.get(99) == "overflow")
    }
}
