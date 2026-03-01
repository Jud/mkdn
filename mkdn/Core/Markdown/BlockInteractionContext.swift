import SwiftUI

/// Per-block interaction state for consumer interaction handlers.
///
/// Carries the source block, async-loaded images, and convenience accessors
/// for common block properties. Because image loading and math rendering are
/// async operations, this is an `@Observable` class so that library-internal
/// views can publish loaded assets and consumer wrappers can reactively
/// observe them.
@MainActor @Observable
public final class BlockInteractionContext: Identifiable {
    public let block: IndexedBlock

    /// Stable identity derived from the block at init time, accessible from any isolation context.
    public nonisolated let id: String

    public private(set) var loadedImage: PlatformTypeConverter.PlatformImage?
    public private(set) var renderedImage: PlatformTypeConverter.PlatformImage?

    // MARK: - Convenience Accessors

    public var blockIndex: Int {
        block.index
    }

    public var blockID: String {
        block.block.id
    }

    public var rawContent: MarkdownBlock {
        block.block
    }

    public var language: String? {
        if case let .codeBlock(lang, _) = block.block { return lang }
        return nil
    }

    public var imageSource: String? {
        if case let .image(source, _) = block.block { return source }
        return nil
    }

    public var imageAlt: String? {
        if case let .image(_, alt) = block.block { return alt }
        return nil
    }

    public var headingLevel: Int? {
        if case let .heading(level, _) = block.block { return level }
        return nil
    }

    public var plainText: String {
        MarkdownTextStorageBuilder.plainText(from: block.block)
    }

    public init(block: IndexedBlock) {
        self.block = block
        id = block.id
    }

    // MARK: - Internal Setters

    func setLoadedImage(_ image: PlatformTypeConverter.PlatformImage?) {
        loadedImage = image
    }

    func setRenderedImage(_ image: PlatformTypeConverter.PlatformImage?) {
        renderedImage = image
    }
}

/// Tracks per-block render lifecycle for consumers who want to display
/// loading indicators or error states for individual blocks.
///
/// Design-only in this phase -- the enum is defined but no handlers consume it.
public enum BlockRenderState: Equatable, Sendable {
    case idle
    case loading
    case rendered
    case error(String)
}
