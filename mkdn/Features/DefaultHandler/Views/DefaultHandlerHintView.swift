import SwiftUI

/// Non-modal banner shown once on first launch, suggesting the user
/// set mkdn as their default Markdown app. Includes a "Set as Default"
/// action button and a dismiss (X) button. Once either is activated,
/// the hint is permanently suppressed via `AppSettings.hasShownDefaultHandlerHint`.
struct DefaultHandlerHintView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var showConfirmation = false
    @State private var isVisible = true

    var body: some View {
        if isVisible, !showConfirmation {
            hintContent
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if showConfirmation {
            confirmationContent
                .transition(.opacity)
        }
    }

    private var hintContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(appSettings.theme.colors.accent)
            Text("Make mkdn your default Markdown viewer?")
                .font(.callout)
                .foregroundStyle(appSettings.theme.colors.foreground)
            Spacer()
            Button("Set as Default") {
                let success = DefaultHandlerService.registerAsDefault()
                if success {
                    showConfirmation = true
                    dismissAfterDelay()
                }
                markHintShown()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button {
                withAnimation(.easeOut(duration: 0.3)) { isVisible = false }
                markHintShown()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(appSettings.theme.colors.foregroundSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var confirmationContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Done! mkdn is now your default Markdown app.")
                .font(.callout)
                .foregroundStyle(appSettings.theme.colors.foreground)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func markHintShown() {
        appSettings.hasShownDefaultHandlerHint = true
    }

    private func dismissAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) { isVisible = false }
        }
    }
}
