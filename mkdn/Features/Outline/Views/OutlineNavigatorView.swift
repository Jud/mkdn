#if os(macOS)
    import SwiftUI

    extension Notification.Name {
        static let outlineToggle = Notification.Name("outlineToggle")
    }

    /// Document outline navigator — a single container that morphs between
    /// a breadcrumb bar and an expanded outline HUD.
    ///
    /// The breadcrumb row IS the header of the container. When expanded, a
    /// search field replaces the breadcrumb and the heading list appears below.
    /// On collapse, a rubber-band pull stretches the container before releasing,
    /// followed by a vertical landing bounce.
    struct OutlineNavigatorView: View {
        @Environment(OutlineState.self) private var outlineState
        @Environment(AppSettings.self) private var appSettings
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        // MARK: - Layout Constants

        private let expandedWidth: CGFloat = 400
        private let expandedHeight: CGFloat = 500
        private let cornerRadius: CGFloat = 10

        // MARK: - State

        @State private var stretchW: CGFloat = 0
        @State private var stretchH: CGFloat = 0
        @State private var settleY: CGFloat = 0
        @State private var entranceY: CGFloat = -40
        @State private var isVisible = false
        @State private var lastBreadcrumbs: [HeadingNode] = []
        @State private var animationTask: Task<Void, Never>?
        @State private var exitTask: Task<Void, Never>?
        @FocusState private var isFilterFocused: Bool

        private var isExpanded: Bool {
            outlineState.isHUDVisible
        }

        private var motion: MotionPreference {
            MotionPreference(reduceMotion: reduceMotion)
        }

        // MARK: - Toggle

        @State private var lastToggleTime: Date = .distantPast

        private func toggle() {
            // Debounce rapid toggles (e.g. notification received by multiple views)
            let now = Date()
            guard now.timeIntervalSince(lastToggleTime) > 0.3 else { return }
            lastToggleTime = now

            animationTask?.cancel()

            if isExpanded {
                animationTask = Task { @MainActor in
                    // Phase 1: Rubber band pull
                    withAnimation(.easeOut(duration: AnimationConstants.outlineStretchDuration)) {
                        stretchW = 18
                        stretchH = 10
                    }
                    try? await Task.sleep(for: .seconds(AnimationConstants.outlineStretchDuration))
                    guard !Task.isCancelled else { return }

                    // Phase 2: Release
                    NSCursor.arrow.set()
                    withAnimation(AnimationConstants.outlineClose) {
                        outlineState.dismissHUD()
                        isFilterFocused = false
                        stretchW = 0
                        stretchH = 0
                    }

                    guard !reduceMotion else { return }

                    try? await Task.sleep(for: .seconds(AnimationConstants.outlineSettleDelay))
                    guard !Task.isCancelled else { return }

                    // Phase 3: Landing bounce
                    withAnimation(AnimationConstants.outlineSettlePop) {
                        settleY = -4
                    }
                    try? await Task.sleep(for: .seconds(AnimationConstants.outlineSettleReturnDelay))
                    guard !Task.isCancelled else { return }

                    withAnimation(AnimationConstants.outlineSettleReturn) {
                        settleY = 0
                    }
                }
            } else {
                stretchW = 0
                stretchH = 0
                settleY = 0
                entranceY = 0
                isVisible = true
                withAnimation(motion.resolved(.outlinePop)) {
                    outlineState.showHUD()
                }
            }
        }

        // MARK: - Body

        var body: some View {
            GeometryReader { geo in
                morphContainer(maxBreadcrumbWidth: geo.size.width * 0.4)
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
                .onKeyPress(.upArrow, phases: .down) { _ in
                    guard isExpanded else { return .ignored }
                    outlineState.moveSelectionUp()
                    return .handled
                }
                .onKeyPress(.downArrow, phases: .down) { _ in
                    guard isExpanded else { return .ignored }
                    outlineState.moveSelectionDown()
                    return .handled
                }
                .onKeyPress(.return, phases: .down) { _ in
                    guard isExpanded else { return .ignored }
                    _ = outlineState.selectAndNavigate()
                    return .handled
                }
                .onKeyPress(.escape, phases: .down) { _ in
                    guard isExpanded else { return .ignored }
                    toggle()
                    return .handled
                }
                .onExitCommand {
                    guard isExpanded else { return }
                    toggle()
                }
                .onChange(of: outlineState.filterQuery) { _, _ in
                    outlineState.applyFilter()
                }
                .onChange(of: outlineState.breadcrumbPath) { _, newPath in
                    if !newPath.isEmpty {
                        lastBreadcrumbs = newPath
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .outlineToggle)) { _ in
                    toggle()
                }
        }

        private func morphContainer(maxBreadcrumbWidth: CGFloat) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                if isExpanded {
                    searchRow
                        .frame(width: expandedWidth)
                } else {
                    breadcrumbRow
                        .frame(maxWidth: maxBreadcrumbWidth)
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
            .background(appSettings.theme.colors.background.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        appSettings.theme.colors.border.opacity(isExpanded ? 0.15 : 0.4),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: .black.opacity(isExpanded ? 0.15 : 0.12),
                radius: isExpanded ? 8 : 4,
                y: isExpanded ? 4 : 2
            )
            .offset(y: entranceY + settleY)
            .opacity(isVisible || isExpanded ? 1 : 0)
            .onChange(of: outlineState.isBreadcrumbVisible) { _, breadcrumbVisible in
                if breadcrumbVisible {
                    isVisible = true
                    entranceY = -40
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                        entranceY = 0
                    }
                } else if !isExpanded {
                    withAnimation(.easeIn(duration: 0.2)) {
                        entranceY = -40
                    }
                    exitTask?.cancel()
                    exitTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(200))
                        guard !Task.isCancelled else { return }
                        isVisible = false
                        lastBreadcrumbs = []
                    }
                }
            }
        }

        // MARK: - Breadcrumb Row

        private var breadcrumbRow: some View {
            HStack(spacing: 4) {
                let livePath = outlineState.breadcrumbPath
                let path = livePath.isEmpty ? lastBreadcrumbs : livePath
                let collapsed = collapsedBreadcrumbs(path)
                ForEach(Array(collapsed.enumerated()), id: \.offset) { index, segment in
                    if index > 0 {
                        Text("\u{203A}")
                            .foregroundStyle(.tertiary)
                            .layoutPriority(1)
                    }
                    switch segment {
                    case .ellipsis:
                        Text("\u{2026}")
                            .foregroundStyle(.quaternary)
                    case let .heading(title):
                        Text(title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .drawingGroup()
        }

        // MARK: - Search Row

        private var searchRow: some View {
            @Bindable var bindableOutlineState = outlineState

            return HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Filter headings\u{2026}", text: $bindableOutlineState.filterQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFilterFocused)

                if !outlineState.filterQuery.isEmpty {
                    Button {
                        outlineState.filterQuery = ""
                        outlineState.applyFilter()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onAppear {
                DispatchQueue.main.async {
                    isFilterFocused = true
                }
            }
        }

        // MARK: - Heading List

        private var headingList: some View {
            let filtered = outlineState.filteredHeadings

            return ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, node in
                            headingRow(node: node, index: index, isSelected: index == outlineState.selectedIndex)
                                .id(node.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onAppear {
                    scrollToSelection(proxy: proxy, filtered: filtered)
                }
                .onChange(of: outlineState.selectedIndex) { _, _ in
                    scrollToSelection(proxy: proxy, filtered: filtered)
                }
            }
        }

        private func scrollToSelection(proxy: ScrollViewProxy, filtered: [HeadingNode]) {
            let idx = outlineState.selectedIndex
            guard idx >= 0, idx < filtered.count else { return }
            proxy.scrollTo(filtered[idx].id, anchor: .center)
        }

        private func headingRow(node: HeadingNode, index: Int, isSelected: Bool) -> some View {
            let isCurrentHeading = node.blockIndex == outlineState.currentHeadingIndex

            return HStack(spacing: 6) {
                if isCurrentHeading {
                    Circle()
                        .fill(appSettings.theme.colors.accent)
                        .frame(width: 5, height: 5)
                } else {
                    Spacer()
                        .frame(width: 5)
                }

                Text(node.title)
                    .font(.system(size: 13, weight: isCurrentHeading ? .semibold : .regular))
                    .foregroundStyle(appSettings.theme.colors.foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.leading, CGFloat((node.level - 1) * 16))
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 32)
            .background(
                isSelected
                    ? appSettings.theme.colors.accent.opacity(0.15)
                    : Color.clear
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onTapGesture {
                outlineState.selectedIndex = index
                _ = outlineState.selectAndNavigate()
            }
        }

        // MARK: - Breadcrumb Collapsing

        private enum BreadcrumbSegment {
            case heading(String)
            case ellipsis
        }

        private func collapsedBreadcrumbs(_ path: [HeadingNode]) -> [BreadcrumbSegment] {
            guard path.count > 3 else {
                return path.map { .heading($0.title) }
            }
            return [
                .heading(path[0].title),
                .ellipsis,
                .heading(path[path.count - 2].title),
                .heading(path[path.count - 1].title),
            ]
        }
    }
#endif
