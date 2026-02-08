import SwiftUI

/// Breathing-dot indicator shown when the editor has unsaved changes.
struct UnsavedIndicator: View {
    @State private var isBreathing = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.yellow)
                .frame(width: 8, height: 8)
                .opacity(isBreathing ? 1.0 : 0.4)
                .animation(AnimationConstants.breathe, value: isBreathing)
            Text("Unsaved")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .help("This file has unsaved changes.")
        .onAppear {
            isBreathing = true
        }
    }
}
