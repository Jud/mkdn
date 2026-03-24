import AppKit
import SwiftUI

@main
struct OutlineMorphApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 800, height: 600)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    }
                }
        }
        .commands {
            CommandMenu("Navigate") {
                Button("Toggle Outline") {
                    NotificationCenter.default.post(name: .toggleOutline, object: nil)
                }
                .keyboardShortcut("j", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let toggleOutline = Notification.Name("toggleOutline")
}

// MARK: - Content View

struct ContentView: View {
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("# Architecture Overview")
                        .font(.title).bold()
                    ForEach(0..<8) { i in
                        Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Paragraph \(i + 1) of the document content that sits behind the overlay.")
                            .font(.body)
                    }
                    Text("## Component Design")
                        .font(.title2).bold()
                    ForEach(0..<8) { i in
                        Text("Implementation details for component \(i + 1). The rendering engine processes markdown blocks sequentially.")
                            .font(.body)
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))

            OutlineMorphView(isExpanded: $isExpanded)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Outline Morph View

struct OutlineMorphView: View {
    @Binding var isExpanded: Bool

    // MARK: - Sample Data

    let breadcrumbs = ["Architecture", "Component Design", "Rendering Engine"]
    let headings: [(level: Int, title: String)] = [
        (1, "Architecture Overview"),
        (2, "System Context"),
        (2, "Component Design"),
        (3, "Rendering Engine"),
        (3, "Layout Manager"),
        (3, "Theme System"),
        (2, "Data Model"),
        (2, "Flow Diagrams"),
        (3, "Render Pipeline"),
        (3, "User Interaction"),
        (2, "Error Handling"),
        (2, "Testing Strategy"),
        (3, "Unit Tests"),
        (3, "Integration Tests"),
        (2, "Implementation Plan"),
        (3, "Phase 1: Foundation"),
        (3, "Phase 2: Core"),
        (3, "Phase 3: Polish"),
    ]

    // MARK: - Layout Constants

    private let expandedWidth: CGFloat = 380
    private let expandedHeight: CGFloat = 460
    private let cornerRadius: CGFloat = 10

    // MARK: - Animation Constants

    static let openSpring: Animation = .spring(response: 0.4, dampingFraction: 0.65)
    static let closeLayout: Animation = .easeOut(duration: 0.2)

    // MARK: - State

    @State private var stretchW: CGFloat = 0
    @State private var stretchH: CGFloat = 0
    @State private var settleY: CGFloat = 0
    @State private var filterText = ""
    @State private var animationTask: Task<Void, Never>?
    @FocusState private var isFilterFocused: Bool

    // MARK: - Toggle

    private func toggle() {
        animationTask?.cancel()

        if isExpanded {
            animationTask = Task { @MainActor in
                // Phase 1: Rubber band pull
                withAnimation(.easeOut(duration: 0.12)) {
                    stretchW = 18
                    stretchH = 10
                }
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }

                // Phase 2: Release
                withAnimation(Self.closeLayout) {
                    isExpanded = false
                    filterText = ""
                    isFilterFocused = false
                    stretchW = 0
                    stretchH = 0
                }
                try? await Task.sleep(for: .milliseconds(190))
                guard !Task.isCancelled else { return }

                // Phase 3: Landing bounce
                withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                    settleY = -4
                }
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    settleY = 0
                }
            }
        } else {
            stretchW = 0
            stretchH = 0
            settleY = 0
            withAnimation(Self.openSpring) {
                isExpanded = true
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                searchRow
                    .frame(width: expandedWidth)
            } else {
                breadcrumbRow
                    .onTapGesture { toggle() }
            }

            if isExpanded {
                headingList
                    .frame(width: expandedWidth)
                    .transition(.opacity)
            }
        }
        .frame(width: isExpanded ? expandedWidth + stretchW : nil)
        .frame(maxHeight: isExpanded ? expandedHeight + stretchH : nil)
        .fixedSize(horizontal: !isExpanded, vertical: !isExpanded)
        .background(.ultraThinMaterial)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.secondary.opacity(isExpanded ? 0.15 : 0.3), lineWidth: 0.5)
        )
        .shadow(
            color: .black.opacity(isExpanded ? 0.2 : 0.1),
            radius: isExpanded ? 12 : 4,
            y: isExpanded ? 6 : 2
        )
        .offset(y: settleY)
        .onReceive(NotificationCenter.default.publisher(for: .toggleOutline)) { _ in
            toggle()
        }
    }

    // MARK: - Breadcrumb Row

    private var breadcrumbRow: some View {
        ZStack {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Text("\u{203A}")
                            .foregroundStyle(.tertiary)
                    }
                    Text(crumb)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - Search Row

    private var searchRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("Filter headings\u{2026}", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFilterFocused)

            if !filterText.isEmpty {
                Button {
                    filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            Button {
                toggle()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            DispatchQueue.main.async {
                isFilterFocused = true
            }
        }
        .onExitCommand {
            toggle()
        }
    }

    // MARK: - Heading List

    private var headingList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(headings.enumerated()), id: \.offset) { index, heading in
                    HStack(spacing: 6) {
                        if index == 3 {
                            Circle()
                                .fill(.blue)
                                .frame(width: 5, height: 5)
                        } else {
                            Spacer().frame(width: 5)
                        }
                        Text(heading.title)
                            .font(.system(size: 13, weight: index == 3 ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .padding(.leading, CGFloat((heading.level - 1) * 16))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 30)
                    .background(index == 3 ? Color.blue.opacity(0.12) : .clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggle()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 800, height: 600)
}
