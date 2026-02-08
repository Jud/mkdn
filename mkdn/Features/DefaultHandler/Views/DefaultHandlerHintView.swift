import SwiftUI

/// Small pulsing orb shown once on first launch, suggesting the user
/// set mkdn as their default Markdown app. Clicking the orb presents a
/// popover with Yes/No buttons. Choosing either option permanently
/// suppresses the orb via `AppSettings.hasShownDefaultHandlerHint`.
struct DefaultHandlerHintView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDialog = false
    @State private var isPulsing = false
    @State private var isHaloExpanded = false
    @State private var popoverAppeared = false

    private let orbColor = AnimationConstants.orbGlowColor

    var body: some View {
        orbVisual
            .hoverScale()
            .onAppear {
                guard !reduceMotion else {
                    isPulsing = true
                    isHaloExpanded = true
                    return
                }
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
            .onChange(of: showDialog) { _, newValue in
                if !newValue {
                    popoverAppeared = false
                }
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
        .scaleEffect(popoverAppeared ? 1.0 : 0.95)
        .opacity(popoverAppeared ? 1.0 : 0)
        .onAppear {
            let animation = reduceMotion
                ? AnimationConstants.reducedCrossfade
                : AnimationConstants.springSettle
            withAnimation(animation) {
                popoverAppeared = true
            }
        }
    }

    private func markHintShown() {
        appSettings.hasShownDefaultHandlerHint = true
    }
}
