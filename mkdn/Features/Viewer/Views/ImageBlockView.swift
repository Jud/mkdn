import SwiftUI

/// Renders a Markdown image with async loading, error placeholders, and path security.
struct ImageBlockView: View {
    let source: String
    let alt: String

    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings
    @State private var loadedImage: NSImage?
    @State private var loadError = false
    @State private var isLoading = true

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    var body: some View {
        Group {
            if isLoading {
                loadingPlaceholder
            } else if let image = loadedImage {
                imageContent(image)
            } else {
                errorPlaceholder
            }
        }
        .task(id: source) { await loadImage() }
    }

    // MARK: - Subviews

    private var loadingPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading image...")
                .font(.caption)
                .foregroundColor(colors.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func imageContent(_ image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            if !alt.isEmpty {
                Text(alt)
                    .font(.caption)
                    .foregroundColor(colors.foregroundSecondary)
            }
        }
    }

    private var errorPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title2)
                .foregroundColor(colors.foregroundSecondary)

            if !alt.isEmpty {
                Text(alt)
                    .font(.caption)
                    .foregroundColor(colors.foregroundSecondary)
            } else {
                Text("Image failed to load")
                    .font(.caption)
                    .foregroundColor(colors.foregroundSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Loading

    private func loadImage() async {
        guard loadedImage == nil, !loadError else { return }

        isLoading = true
        defer { isLoading = false }

        guard let resolvedURL = resolveSource() else {
            loadError = true
            return
        }

        if resolvedURL.isFileURL {
            loadLocalImage(url: resolvedURL)
        } else {
            await loadRemoteImage(url: resolvedURL)
        }
    }

    private func loadLocalImage(url: URL) {
        let image = NSImage(contentsOf: url)
        if let image {
            loadedImage = image
        } else {
            loadError = true
        }
    }

    private func loadRemoteImage(url: URL) async {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)
            if let image = NSImage(data: data) {
                loadedImage = image
            } else {
                loadError = true
            }
        } catch {
            loadError = true
        }
    }

    // MARK: - Source Resolution

    private func resolveSource() -> URL? {
        if let url = URL(string: source) {
            let scheme = url.scheme?.lowercased()
            if scheme == "http" || scheme == "https" {
                return url
            }

            if scheme == "file" {
                return validateLocalPath(url)
            }
        }

        return resolveRelativePath(source)
    }

    private func resolveRelativePath(_ path: String) -> URL? {
        guard let fileURL = documentState.currentFileURL else {
            return nil
        }
        let baseDirectory = fileURL.deletingLastPathComponent()
        let resolved = baseDirectory.appendingPathComponent(path).standardized
        return validateLocalPath(resolved)
    }

    private func validateLocalPath(_ url: URL) -> URL? {
        guard let fileURL = documentState.currentFileURL else {
            return nil
        }
        let baseDirectory = fileURL.deletingLastPathComponent().standardized
        let resolved = url.standardized
        guard resolved.path.hasPrefix(baseDirectory.path) else {
            return nil
        }
        return resolved
    }
}
