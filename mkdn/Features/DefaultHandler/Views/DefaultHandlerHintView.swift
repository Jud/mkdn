import SwiftUI

/// Small pulsing orb shown once on first launch, suggesting the user
/// set mkdn as their default Markdown app. Clicking the orb presents a
/// popover with Yes/No buttons. Choosing either option permanently
/// suppresses the orb via `AppSettings.hasShownDefaultHandlerHint`.
struct DefaultHandlerHintView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var showDialog = false
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(appSettings.theme.colors.accent)
            .frame(width: 10, height: 10)
            .shadow(
                color: appSettings.theme.colors.accent.opacity(0.6),
                radius: isPulsing ? 8 : 4
            )
            .scaleEffect(isPulsing ? 1.0 : 0.85)
            .opacity(isPulsing ? 1.0 : 0.4)
            .onAppear {
                withAnimation(AnimationConstants.defaultHandlerOrbPulse) {
                    isPulsing = true
                }
            }
            .onTapGesture {
                showDialog = true
            }
            .popover(isPresented: $showDialog, arrowEdge: .bottom) {
                VStack(spacing: 12) {
                    Text("Would you like to make mkdn your default Markdown reader?")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button("No") {
                            showDialog = false
                            markHintShown()
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("Yes") {
                            DefaultHandlerService.registerAsDefault()
                            showDialog = false
                            markHintShown()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(16)
            }
    }

    private func markHintShown() {
        appSettings.hasShownDefaultHandlerHint = true
    }
}
