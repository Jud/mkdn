import SwiftUI

/// Custom pill-shaped find bar that floats in the top-right corner
/// of the preview viewport.
///
/// Provides a text field for incremental search, a match count label
/// ("N of M"), previous/next navigation chevrons, and a close button.
/// Uses `.ultraThinMaterial` background with Capsule clip for frosted
/// glass appearance consistent with other overlay surfaces.
///
/// ## Keyboard Contract
///
/// - **Return**: Advance to next match
/// - **Shift+Return**: Return to previous match
/// - **Escape**: Dismiss the find bar
///
/// ## Animation Contract
///
/// Entrance and exit transitions are applied externally via
/// ``ContentView``'s `.transition(.asymmetric(...))` modifier.
/// The dismiss action wraps state changes in `withAnimation(quickFade)`
/// (or `reducedInstant` under Reduce Motion) so the removal
/// transition animates correctly.
struct FindBarView: View {
    @Environment(FindState.self) private var findState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var isInputFocused: Bool

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    var body: some View {
        @Bindable var bindableFindState = findState

        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            searchField(text: $bindableFindState.query)

            if !findState.query.isEmpty {
                matchCountLabel
            }

            navigationButtons

            closeButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .opacity(findState.isVisible ? 1 : 0)
        .scaleEffect(findState.isVisible ? 1 : 0.95)
        .animation(
            reduceMotion ? AnimationConstants.reducedCrossfade : AnimationConstants.springSettle,
            value: findState.isVisible
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
        .onChange(of: findState.isVisible) { _, isVisible in
            if isVisible {
                DispatchQueue.main.async {
                    isInputFocused = true
                }
            }
        }
    }

    // MARK: - Search Field

    private func searchField(text: Binding<String>) -> some View {
        TextField("Find\u{2026}", text: text)
            .textFieldStyle(.plain)
            .focused($isInputFocused)
            .onSubmit {
                findState.nextMatch()
            }
            .onKeyPress(.return, phases: .down) { keyPress in
                if keyPress.modifiers.contains(.shift) {
                    findState.previousMatch()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.escape, phases: .down) { _ in
                dismissFindBar()
                return .handled
            }
    }

    // MARK: - Match Count

    private var matchCountLabel: some View {
        Group {
            if findState.matchCount > 0 {
                Text("\(findState.currentMatchIndex + 1) of \(findState.matchCount)")
            } else {
                Text("No matches")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .fixedSize()
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 8) {
            Button {
                findState.previousMatch()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(findState.matchCount == 0)

            Button {
                findState.nextMatch()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(findState.matchCount == 0)
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            dismissFindBar()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dismiss

    private func dismissFindBar() {
        isInputFocused = false
        findState.dismiss()
    }
}
