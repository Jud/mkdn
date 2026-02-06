import SwiftUI

/// Subtle indicator shown when the file on disk has changed.
struct OutdatedIndicator: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            try? appState.reloadFile()
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                Text("File changed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("The file has changed on disk. Click to reload.")
    }
}
