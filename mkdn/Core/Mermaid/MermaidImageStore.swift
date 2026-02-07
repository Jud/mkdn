import AppKit

/// Bounded LRU cache for rasterized `NSImage` instances, keyed by stable DJB2 hash.
///
/// Sits between the view layer and ``MermaidRenderer`` actor, holding the expensive-to-compute
/// final rasterized output so that recycled ``MermaidBlockView`` instances can restore their
/// rendered state synchronously in `init`, avoiding the re-render cycle caused by LazyVStack
/// view recycling.
///
/// `@MainActor` because `NSImage` is not `Sendable` and view init/body runs on the main actor.
/// Separate from ``MermaidRenderer`` to avoid cross-isolation complexity.
@MainActor
final class MermaidImageStore {
    static let shared = MermaidImageStore()

    private var storage: [UInt64: NSImage] = [:]
    private var accessOrder: [UInt64] = []
    private let capacity: Int

    init(capacity: Int = 50) {
        self.capacity = capacity
    }

    /// Returns the cached image for the given Mermaid source code and theme, or `nil` on a miss.
    /// A hit promotes the entry to most-recently-used.
    func get(_ code: String, theme: AppTheme = .solarizedDark) -> NSImage? {
        let key = mermaidStableHash(code + theme.rawValue)
        guard let image = storage[key] else {
            return nil
        }
        promoteToMostRecent(key)
        return image
    }

    /// Stores a rasterized image for the given Mermaid source code and theme.
    /// If the cache is at capacity, the least-recently-used entry is evicted first.
    func store(_ code: String, image: NSImage, theme: AppTheme = .solarizedDark) {
        let key = mermaidStableHash(code + theme.rawValue)
        if storage[key] != nil {
            storage[key] = image
            promoteToMostRecent(key)
            return
        }

        if accessOrder.count >= capacity {
            evictLeastRecentlyUsed()
        }

        storage[key] = image
        accessOrder.append(key)
    }

    /// Clears the entire cache. Call on file reload or theme change.
    func removeAll() {
        storage.removeAll()
        accessOrder.removeAll()
    }

    var count: Int {
        storage.count
    }

    var isEmpty: Bool {
        storage.isEmpty
    }
}

// MARK: - Internal

private extension MermaidImageStore {
    func promoteToMostRecent(_ key: UInt64) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }

    func evictLeastRecentlyUsed() {
        guard let lruKey = accessOrder.first else { return }
        accessOrder.removeFirst()
        storage.removeValue(forKey: lruKey)
    }
}
