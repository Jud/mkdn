import SwiftUI

/// Hover-revealed copy button for code blocks.
///
/// Displays a `doc.on.doc` icon that toggles to a `checkmark` on successful copy,
/// then reverts after a brief delay. Uses ``AnimationConstants/quickShift`` for the
/// icon transition and `.ultraThinMaterial` background for theme-adaptive appearance.
struct CodeBlockCopyButton: View {
    let codeBlockColors: CodeBlockColorInfo
    let onCopy: () -> Void
    @State private var isCopied = false

    var body: some View {
        Button(action: performCopy) {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func performCopy() {
        onCopy()
        withAnimation(AnimationConstants.quickShift) {
            isCopied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(AnimationConstants.quickShift) {
                isCopied = false
            }
        }
    }
}
