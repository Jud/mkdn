import SwiftUI

/// Pulsing orb shown when the on-disk file has changed since last load.
/// Clicking the orb presents a popover asking whether to reload.
/// On confirmation, calls `documentState.reloadFile()`.
struct FileChangeOrbView: View {
    @Environment(DocumentState.self) private var documentState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDialog = false
    @State private var isPulsing = false
    @State private var isHaloExpanded = false
    @State private var popoverAppeared = false

    private let orbColor = AnimationConstants.fileChangeOrbColor

    var body: some View {
        orbVisual
            .hoverScale()
            .onAppear {
                guard !reduceMotion else {
                    isPulsing = true
                    isHaloExpanded = true
                    return
                }
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
}
