#if os(iOS)
    import SwiftUI
    import UIKit

    /// Renders a Markdown image with async loading, error placeholders, and path resolution on iOS.
    ///
    /// Images render at their natural size when smaller than the available width, and
    /// scale down to fit when larger. Aspect ratio is always preserved. Publishes the
    /// loaded image to ``BlockInteractionContext/loadedImage`` so consumer wrappers
    /// can observe it.
    struct ImageBlockViewiOS: View {
        let source: String
        let alt: String
        let theme: AppTheme
        let baseURL: URL?
        let context: BlockInteractionContext?

        @State private var loadedImage: UIImage?
        @State private var loadError = false
        @State private var isLoading = true

        private var colors: ThemeColors {
            theme.colors
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
            .accessibilityLabel(alt.isEmpty ? "Image" : alt)
            .accessibilityAddTraits(.isImage)
        }

        // MARK: - Subviews

        private var loadingPlaceholder: some View {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading image...")
                    .font(.caption)
                    .foregroundColor(colors.foregroundSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }

        private func imageContent(_ image: UIImage) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                if !alt.isEmpty {
                    Text(alt)
                        .font(.caption)
                        .foregroundColor(colors.foregroundSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data)
            else {
                loadError = true
                return
            }
            loadedImage = image
            context?.setLoadedImage(image)
        }

        private func loadRemoteImage(url: URL) async {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                let (data, _) = try await URLSession.shared.data(for: request)
                if let image = UIImage(data: data) {
                    loadedImage = image
                    context?.setLoadedImage(image)
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
            guard let base = baseURL else {
                return nil
            }
            let resolved = base.appendingPathComponent(path).standardized
            return validateLocalPath(resolved)
        }

        private func validateLocalPath(_ url: URL) -> URL? {
            guard let base = baseURL else {
                return nil
            }
            let resolved = url.standardized
            guard resolved.path.hasPrefix(base.standardized.path) else {
                return nil
            }
            return resolved
        }
    }
#endif
