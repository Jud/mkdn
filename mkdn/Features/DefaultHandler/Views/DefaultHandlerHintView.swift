import SwiftUI

/// Small pulsing orb shown once on first launch, suggesting the user
/// set mkdn as their default Markdown app. Clicking the orb presents a
/// popover with Yes/No buttons. Choosing either option permanently
/// suppresses the orb via `AppSettings.hasShownDefaultHandlerHint`.
struct DefaultHandlerHintView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var showDialog = false
    @State private var isPulsing = false
    @State private var isHaloExpanded = false

    private let orbColor = AnimationConstants.orbGlowColor

    var body: some View {
        orbVisual
            .onAppear {
                withAnimation(AnimationConstants.defaultHandlerOrbPulse) {
                    isPulsing = true
                }
                withAnimation(AnimationConstants.orbHaloBloom) {
                    isHaloExpanded = true
                }
            }
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onTapGesture {
                showDialog = true
            }
            .popover(isPresented: $showDialog, arrowEdge: .bottom) {
                popoverContent
            }
    }

    private var orbVisual: some View {
        OrbVisual(
            color: orbColor,
            isPulsing: isPulsing,
            isHaloExpanded: isHaloExpanded
        )
    }

    private var popoverContent: some View {
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
        .fixedSize()
    }

    private func markHintShown() {
        appSettings.hasShownDefaultHandlerHint = true
    }
}
