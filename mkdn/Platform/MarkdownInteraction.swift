import SwiftUI

/// Carries interaction handler closures through the SwiftUI environment
/// from consumer-applied view modifiers down to internal block views.
///
/// Each field corresponds to a view modifier in `MarkdownInteractionModifiers`.
/// Modifiers use `transformEnvironment(\.markdownInteraction)` to set their
/// respective field, enabling composable chaining without ordering conflicts.
@MainActor
public struct MarkdownInteraction {
    public var onBlockTapped: ((BlockInteractionContext) -> Void)?
    public var onLinkTapped: ((URL, LinkNavigationHandler.LinkDestination) -> Bool)?
    public var blockContextMenuBuilder: ((BlockInteractionContext) -> AnyView)?
    public var onBlockSizeChanged: ((_ blockIndex: Int, _ size: CGSize) -> Void)?
    public var scrollTarget: Binding<BlockScrollTarget?>?
    public var onCodeCopy: ((_ code: String, _ language: String?) -> Void)?
    public var onVisibleBlocksChanged: ((Set<Int>) -> Void)?
    var onScrollOffsetChanged: ((CGFloat) -> Void)?
    public var blockViewWrapperClosure: ((BlockInteractionContext, AnyView) -> AnyView)?

    public init() {}
}

// MARK: - Environment Key

struct MarkdownInteractionKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = MarkdownInteraction()
}

extension EnvironmentValues {
    var markdownInteraction: MarkdownInteraction {
        get { self[MarkdownInteractionKey.self] }
        set { self[MarkdownInteractionKey.self] = newValue }
    }
}
