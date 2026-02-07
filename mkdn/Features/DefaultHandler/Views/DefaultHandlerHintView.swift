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
        ZStack {
            outerHalo
            midGlow
            innerCore
        }
        .opacity(isPulsing ? 1.0 : 0.4)
    }

    private var outerHalo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        orbColor.opacity(isHaloExpanded ? 0.3 : 0.1),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 20
                )
            )
            .frame(width: 40, height: 40)
            .scaleEffect(isHaloExpanded ? 1.1 : 0.85)
    }

    private var midGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        orbColor.opacity(0.8),
                        orbColor.opacity(0.15),
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 8
                )
            )
            .frame(width: 18, height: 18)
            .shadow(
                color: orbColor.opacity(isPulsing ? 0.6 : 0.2),
                radius: isPulsing ? 10 : 4
            )
            .scaleEffect(isPulsing ? 1.0 : 0.85)
    }

    private var innerCore: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.9),
                        orbColor,
                        orbColor.opacity(0.3),
                    ],
                    center: UnitPoint(x: 0.4, y: 0.35),
                    startRadius: 0,
                    endRadius: 5
                )
            )
            .frame(width: 8, height: 8)
            .opacity(isPulsing ? 1.0 : 0.5)
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
