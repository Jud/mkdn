import SwiftUI

// MARK: - Essential View Modifiers

public extension View {
    /// Attaches a handler that fires when the user taps a rendered Markdown block.
    ///
    /// The handler receives a ``BlockInteractionContext`` with the tapped block's
    /// index, type, content, and any loaded images.
    ///
    /// - Parameter handler: Closure invoked with the tapped block's interaction context.
    func onBlockTapped(
        _ handler: @escaping (BlockInteractionContext) -> Void
    ) -> some View {
        transformEnvironment(\.markdownInteraction) { interaction in
            interaction.onBlockTapped = handler
        }
    }

    /// Attaches a handler that intercepts link taps in rendered Markdown text.
    ///
    /// The handler receives the tapped URL and its classified
    /// ``LinkNavigationHandler/LinkDestination`` (localMarkdown, external,
    /// otherLocalFile). Return `true` to indicate the link was handled, or
    /// `false` to fall through to default behavior.
    ///
    /// - Parameter handler: Closure invoked with the URL and its destination classification.
    func onLinkTapped(
        _ handler: @escaping (URL, LinkNavigationHandler.LinkDestination) -> Bool
    ) -> some View {
        transformEnvironment(\.markdownInteraction) { interaction in
            interaction.onLinkTapped = handler
        }
    }

    /// Attaches a context menu builder that provides long-press menus on rendered blocks.
    ///
    /// The builder receives a ``BlockInteractionContext`` for constructing
    /// contextual menu items. When ``blockViewWrapper`` is also set, this
    /// modifier is suppressed on wrapped blocks -- the wrapper is responsible
    /// for adding its own `.contextMenu` if desired.
    ///
    /// - Parameter content: A `@ViewBuilder` closure returning the context menu content.
    func blockContextMenu(
        @ViewBuilder _ content: @escaping (BlockInteractionContext) -> some View
    ) -> some View {
        transformEnvironment(\.markdownInteraction) { interaction in
            interaction.blockContextMenuBuilder = { context in
                AnyView(content(context))
            }
        }
    }

    /// Attaches a handler that reports size changes for individual rendered blocks.
    ///
    /// Called when a block's geometry changes, enabling consumers to track
    /// per-block dimensions for custom layout or analytics.
    ///
    /// - Parameter handler: Closure invoked with the block index and its new size.
    func onBlockSizeChanged(
        _ handler: @escaping (_ blockIndex: Int, _ size: CGSize) -> Void
    ) -> some View {
        transformEnvironment(\.markdownInteraction) { interaction in
            interaction.onBlockSizeChanged = handler
        }
    }

    /// Binds a scroll target for programmatic scroll-to-block behavior.
    ///
    /// Set the binding's value to a ``BlockScrollTarget`` to scroll to that
    /// block. The binding resets to `nil` after scrolling completes.
    ///
    /// - Parameter target: A binding to an optional scroll target.
    func scrollTarget(
        _ target: Binding<BlockScrollTarget?>
    ) -> some View {
        transformEnvironment(\.markdownInteraction) { interaction in
            interaction.scrollTarget = target
        }
    }
}

// MARK: - Desirable View Modifiers

public extension View {
    /// Attaches a handler that fires when the user copies code from a code block.
    ///
    /// Enables consumers to integrate with clipboard management or analytics
    /// when code is copied via the built-in copy button.
    ///
    /// - Parameter handler: Closure invoked with the code string and optional language identifier.
    func onCodeCopy(
        _ handler: @escaping (_ code: String, _ language: String?) -> Void
    ) -> some View {
        transformEnvironment(\.markdownInteraction) { interaction in
            interaction.onCodeCopy = handler
        }
    }

    /// Attaches a handler that reports which blocks are currently visible in the scroll viewport.
    ///
    /// Enables scroll-spy behavior such as highlighting the current section
    /// in a table of contents or lazy-loading resources for visible blocks.
    ///
    /// - Parameter handler: Closure invoked with the set of visible block indices.
    func onVisibleBlocksChanged(
        _ handler: @escaping (Set<Int>) -> Void
    ) -> some View {
        transformEnvironment(\.markdownInteraction) { interaction in
            interaction.onVisibleBlocksChanged = handler
        }
    }
}

// MARK: - Power View Modifier

public extension View {
    /// Wraps each rendered block with custom SwiftUI chrome.
    ///
    /// The wrapper receives the ``BlockInteractionContext`` and the raw default
    /// view as `AnyView`. The default view arrives **without** any library
    /// gesture modifiers applied, giving the consumer full control.
    ///
    /// When this modifier is set:
    /// - ``blockContextMenu`` is suppressed on wrapped blocks.
    /// - ``onBlockTapped`` still fires through (single tap, no conflict).
    /// - The consumer can re-add `.contextMenu` inside their wrapper if desired.
    ///
    /// - Parameter wrapper: A `@ViewBuilder` closure receiving the context and raw default view.
    func blockViewWrapper(
        @ViewBuilder _ wrapper: @escaping (BlockInteractionContext, AnyView) -> some View
    ) -> some View {
        transformEnvironment(\.markdownInteraction) { interaction in
            interaction.blockViewWrapperClosure = { context, view in
                AnyView(wrapper(context, view))
            }
        }
    }
}
