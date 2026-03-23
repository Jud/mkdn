#if os(macOS)
    import SwiftUI

    /// Collapsed breadcrumb bar showing the current heading path.
    ///
    /// Displays heading ancestors as text segments separated by chevron
    /// characters. The entire bar is a single click target that opens
    /// the outline HUD. Visibility is controlled by `isVisible` via opacity.
    struct OutlineBreadcrumbBar: View {
        let breadcrumbPath: [HeadingNode]
        let isVisible: Bool
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 4) {
                    ForEach(Array(breadcrumbPath.enumerated()), id: \.element.id) { index, node in
                        if index > 0 {
                            Text("\u{203A}") // single right-pointing angle quotation mark
                                .foregroundStyle(.tertiary)
                                .layoutPriority(1)
                        }
                        Text(node.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 500)
            .opacity(isVisible ? 1 : 0)
        }
    }
#endif
