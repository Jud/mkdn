#if os(macOS)
    import SwiftUI

    /// Combined breadcrumb bar and outline HUD for document heading navigation.
    ///
    /// A single morphing component: the container (frame, background, clipShape,
    /// shadow, cornerRadius) is shared between breadcrumb and HUD states and
    /// animates continuously. Content inside cross-fades via `.transition(.opacity)`.
    struct OutlineNavigatorView: View {
        @Environment(OutlineState.self) private var outlineState
        @Environment(AppSettings.self) private var appSettings
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        @FocusState private var isFilterFocused: Bool

        private var isExpanded: Bool {
            outlineState.isHUDVisible
        }

        private var motion: MotionPreference {
            MotionPreference(reduceMotion: reduceMotion)
        }

        var body: some View {
            ZStack(alignment: .top) {
                // Click-outside-to-dismiss scrim (only when expanded).
                if isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(motion.resolved(.springSettle)) {
                                outlineState.dismissHUD()
                            }
                        }
                }

                // Single morphing container.
                outlineContainer
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }

        // MARK: - Morphing Container

        // The CONTAINER (frame, background, clipShape, shadow, cornerRadius)
        // is shared and animates continuously. Content cross-fades inside.

        private var outlineContainer: some View {
            VStack(spacing: 0) {
                if isExpanded {
                    filterField
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .transition(.opacity)

                    Divider()
                        .padding(.horizontal, 8)
                        .transition(.opacity)

                    headingList
                        .transition(.opacity)
                } else {
                    breadcrumbContent
                        .transition(.opacity)
                }
            }
            // SHARED container shell — these animate continuously:
            .frame(maxWidth: isExpanded ? 400 : 500)
            .frame(maxHeight: isExpanded ? 500 : nil)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 12 : 8))
            .shadow(
                color: isExpanded ? .black.opacity(0.15) : .clear,
                radius: isExpanded ? 8 : 0,
                y: isExpanded ? 4 : 0
            )
            .opacity(outlineState.isBreadcrumbVisible || isExpanded ? 1 : 0)
            .animation(motion.resolved(.springSettle), value: isExpanded)
            .animation(motion.resolved(.fadeIn), value: outlineState.isBreadcrumbVisible)
            .padding(.horizontal, 16)
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
                withAnimation(motion.resolved(.springSettle)) {
                    _ = outlineState.selectAndNavigate()
                }
                return .handled
            }
            .onKeyPress(.escape, phases: .down) { _ in
                guard isExpanded else { return .ignored }
                withAnimation(motion.resolved(.springSettle)) {
                    outlineState.dismissHUD()
                }
                return .handled
            }
            .onChange(of: outlineState.isHUDVisible) { _, isVisible in
                if isVisible {
                    DispatchQueue.main.async {
                        isFilterFocused = true
                    }
                }
            }
            .onChange(of: outlineState.filterQuery) { _, _ in
                outlineState.applyFilter()
            }
        }

        // MARK: - Breadcrumb Content

        private var breadcrumbContent: some View {
            Button {
                withAnimation(motion.resolved(.springSettle)) {
                    outlineState.showHUD()
                }
            } label: {
                HStack(spacing: 4) {
                    ForEach(
                        Array(outlineState.breadcrumbPath.enumerated()),
                        id: \.element.id
                    ) { index, node in
                        if index > 0 {
                            Text("\u{203A}")
                                .foregroundStyle(.tertiary)
                                .layoutPriority(1)
                        }
                        Text(node.title)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }

        // MARK: - Filter Field

        private var filterField: some View {
            @Bindable var bindableOutlineState = outlineState

            return HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Filter headings\u{2026}", text: $bindableOutlineState.filterQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFilterFocused)
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

            return Button {
                outlineState.selectedIndex = index
                withAnimation(motion.resolved(.springSettle)) {
                    _ = outlineState.selectAndNavigate()
                }
            } label: {
                HStack(spacing: 6) {
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
            }
            .buttonStyle(.plain)
        }
    }
#endif
