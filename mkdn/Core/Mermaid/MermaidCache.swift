import Foundation

/// Bounded LRU cache for rendered SVG strings, keyed by stable DJB2 hash.
///
/// Internal to `MermaidRenderer` actor -- no `Sendable` requirement.
/// When at capacity, the least-recently-accessed entry is evicted on insert.
struct MermaidCache {
    private var storage: [UInt64: String] = [:]
    private var accessOrder: [UInt64] = []
    private let capacity: Int

    init(capacity: Int = 50) {
        self.capacity = capacity
    }

    /// Returns the cached value for `key`, or `nil` on a miss.
    /// A hit promotes the entry to most-recently-used.
    mutating func get(_ key: UInt64) -> String? {
        guard let value = storage[key] else {
            return nil
        }
        promoteToMostRecent(key)
        return value
    }

    /// Inserts or updates the entry for `key`.
    /// If the cache is at capacity, the least-recently-used entry is evicted first.
    mutating func set(_ key: UInt64, value: String) {
        if storage[key] != nil {
            storage[key] = value
            promoteToMostRecent(key)
            return
        }

        if accessOrder.count >= capacity {
            evictLeastRecentlyUsed()
        }

        storage[key] = value
        accessOrder.append(key)
    }

    mutating func removeAll() {
        storage.removeAll()
        accessOrder.removeAll()
    }

    var count: Int {
        storage.count
    }
}

// MARK: - Internal

private extension MermaidCache {
    mutating func promoteToMostRecent(_ key: UInt64) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }

    mutating func evictLeastRecentlyUsed() {
        guard let lruKey = accessOrder.first else { return }
        accessOrder.removeFirst()
        storage.removeValue(forKey: lruKey)
    }
}

// MARK: - Stable Hashing

/// DJB2 hash producing a stable, deterministic integer for a given string.
/// Unlike `.hashValue`, this returns the same value across process launches.
func mermaidStableHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 5_381
    for byte in string.utf8 {
        hash = hash &* 33 &+ UInt64(byte)
    }
    return hash
}
