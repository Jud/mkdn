#if os(macOS)
    import SwiftUI

    /// Document outline navigator — a single container that morphs between
    /// a breadcrumb bar and an expanded outline HUD.
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
            outlineContainer
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }

        // MARK: - Morphing Container

        private var outlineContainer: some View {
            ZStack(alignment: .top) {
                // Breadcrumb — always rendered for stable sizing.
                breadcrumbContent
                    .opacity(isExpanded ? 0 : 1)

                // HUD content — inserted/removed.
                if isExpanded {
                    VStack(spacing: 0) {
                        filterField
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                        Divider()
                            .padding(.horizontal, 8)

                        headingList
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: isExpanded ? 400 : 500)
            .frame(maxHeight: isExpanded ? 500 : nil)
            // Prevent the spring from shrinking below the breadcrumb's intrinsic height.
            .frame(minHeight: 32)
            .fixedSize(horizontal: !isExpanded, vertical: !isExpanded)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 12 : 8))
            .shadow(
                color: isExpanded ? .black.opacity(0.15) : .clear,
                radius: isExpanded ? 8 : 0,
                y: isExpanded ? 4 : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: isExpanded ? 12 : 8))
            .opacity(outlineState.isBreadcrumbVisible || isExpanded ? 1 : 0)
            .animation(motion.resolved(.outlinePop), value: isExpanded)
            .animation(motion.resolved(.fadeIn), value: outlineState.isBreadcrumbVisible)
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
                withAnimation(motion.resolved(.outlinePop)) {
                    _ = outlineState.selectAndNavigate()
                }
                return .handled
            }
            .onKeyPress(.escape, phases: .down) { _ in
                guard isExpanded else { return .ignored }
                withAnimation(motion.resolved(.outlinePop)) {
                    outlineState.dismissHUD()
                }
                return .handled
            }
            .onExitCommand {
                guard isExpanded else { return }
                withAnimation(motion.resolved(.outlinePop)) {
                    outlineState.dismissHUD()
                }
            }
            .onChange(of: outlineState.isHUDVisible) { _, isVisible in
                if isVisible {
                    DispatchQueue.main.async {
                        isFilterFocused = true
                    }
                } else {
                    isFilterFocused = false
                }
            }
            .onChange(of: outlineState.filterQuery) { _, _ in
                outlineState.applyFilter()
            }
        }

        // MARK: - Breadcrumb Content

        private var breadcrumbContent: some View {
            Button {
                withAnimation(motion.resolved(.outlinePop)) {
                    outlineState.showHUD()
                }
            } label: {
                HStack(spacing: 4) {
                    let collapsed = collapsedBreadcrumbs(outlineState.breadcrumbPath)
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
                                .truncationMode(.tail)
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            // Tinted background so breadcrumb is visible over any content.
            .background(appSettings.theme.colors.background.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(appSettings.theme.colors.border.opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
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
                withAnimation(motion.resolved(.outlinePop)) {
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

        // MARK: - Breadcrumb Collapsing

        private enum BreadcrumbSegment {
            case heading(String)
            case ellipsis
        }

        /// Show first + last two headings, collapse middle with ellipsis.
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
