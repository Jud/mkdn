import SwiftUI

/// Pulsing orb shown when the on-disk file has changed since last load.
/// Clicking the orb presents a popover asking whether to reload.
/// On confirmation, calls `documentState.reloadFile()`.
struct FileChangeOrbView: View {
    @Environment(DocumentState.self) private var documentState
    @State private var showDialog = false
    @State private var isPulsing = false
    @State private var isHaloExpanded = false

    private let orbColor = AnimationConstants.fileChangeOrbColor

    var body: some View {
        orbVisual
            .onAppear {
                withAnimation(AnimationConstants.fileChangeOrbPulse) {
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
                    endRadius: 10
                )
            )
            .frame(width: 22, height: 22)
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
                    endRadius: 7
                )
            )
            .frame(width: 12, height: 12)
            .opacity(isPulsing ? 1.0 : 0.5)
    }

    private var popoverContent: some View {
        VStack(spacing: 12) {
            Text("There are changes to this file. Would you like to reload?")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("No") {
                    showDialog = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Yes") {
                    try? documentState.reloadFile()
                    showDialog = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .fixedSize()
    }
}
