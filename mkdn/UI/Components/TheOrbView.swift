import SwiftUI

/// Unified stateful orb indicator that consolidates file-change and
/// default-handler prompts into a single, color-coded orb.
///
/// The orb resolves the highest-priority active ``OrbState`` from the
/// environment (``DocumentState`` and ``AppSettings``), renders via
/// ``OrbVisual``, and provides per-state tap-to-popover interactions.
/// When auto-reload is enabled and no unsaved changes exist, a file-change
/// event triggers a single breathing cycle (~5s) before automatic reload.
///
/// Handles its own visibility (hidden when idle), positioning (bottom-right),
/// and transition animations internally.
struct TheOrbView: View {
    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentColor: Color = AnimationConstants.orbDefaultHandlerColor
    @State private var isPulsing = false
    @State private var isHaloExpanded = false
    @State private var showPopover = false
    @State private var popoverAppeared = false
    @State private var popoverActiveState: OrbState = .idle
    @State private var autoReloadTask: Task<Void, Never>?

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    /// Computes the highest-priority active orb state.
    private var activeState: OrbState {
        var states: [OrbState] = []

        if documentState.isFileOutdated {
            states.append(.fileChanged)
        }
        if !appSettings.hasShownDefaultHandlerHint {
            states.append(.defaultHandler)
        }

        return states.max() ?? .idle
    }

    var body: some View {
        Group {
            if activeState.isVisible {
                orbContent
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .animation(motion.resolved(.fadeIn) ?? AnimationConstants.reducedInstant),
                            removal: .scale(scale: 0.5)
                                .combined(with: .opacity)
                                .animation(motion.resolved(.fadeOut) ?? AnimationConstants.reducedInstant)
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(16)
        .onChange(of: activeState) { oldState, newState in
            handleStateChange(from: oldState, to: newState)
        }
        .onChange(of: documentState.isFileOutdated) { _, isOutdated in
            if isOutdated {
                startAutoReloadIfNeeded()
            }
        }
    }

    // MARK: - Orb Content

    private var orbContent: some View {
        OrbVisual(
            color: currentColor,
            isPulsing: isPulsing,
            isHaloExpanded: isHaloExpanded
        )
        .hoverScale()
        .onAppear {
            currentColor = activeState.color
            startPulseAnimations()
            startAutoReloadIfNeeded()
        }
        .onDisappear {
            isPulsing = false
            isHaloExpanded = false
            cancelAutoReload()
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            handleTap()
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            popoverContent
        }
        .onChange(of: showPopover) { _, isShowing in
            if !isShowing {
                popoverAppeared = false
            }
        }
    }

    // MARK: - Pulse Animations

    private func startPulseAnimations() {
        guard motion.allowsContinuousAnimation else {
            isPulsing = true
            isHaloExpanded = true
            return
        }
        withAnimation(motion.resolved(.breathe)) {
            isPulsing = true
        }
        withAnimation(motion.resolved(.haloBloom)) {
            isHaloExpanded = true
        }
    }

    // MARK: - State Change

    private func handleStateChange(from _: OrbState, to newState: OrbState) {
        withAnimation(motion.resolved(.crossfade)) {
            currentColor = newState.color
        }
        if newState != .fileChanged {
            cancelAutoReload()
        } else {
            startAutoReloadIfNeeded()
        }
    }

    // MARK: - Auto-Reload Timer

    private func startAutoReloadIfNeeded() {
        cancelAutoReload()

        guard activeState == .fileChanged,
              appSettings.autoReloadEnabled,
              !documentState.hasUnsavedChanges
        else {
            return
        }

        autoReloadTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            try? documentState.reloadFile()
        }
    }

    private func cancelAutoReload() {
        autoReloadTask?.cancel()
        autoReloadTask = nil
    }

    // MARK: - Tap Handling

    private func handleTap() {
        cancelAutoReload()
        popoverActiveState = activeState
        showPopover = true
    }

    // MARK: - Popover Content

    @ViewBuilder
    private var popoverContent: some View {
        switch popoverActiveState {
        case .defaultHandler:
            defaultHandlerPopover
        case .fileChanged:
            fileChangedPopover
        case .updateAvailable:
            updateAvailablePopover
        case .idle:
            EmptyView()
        }
    }

    private var defaultHandlerPopover: some View {
        VStack(spacing: 12) {
            Text("Would you like to make mkdn your default Markdown reader?")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("No") {
                    showPopover = false
                    appSettings.hasShownDefaultHandlerHint = true
                }
                .keyboardShortcut(.cancelAction)

                Button("Yes") {
                    DefaultHandlerService.registerAsDefault()
                    showPopover = false
                    appSettings.hasShownDefaultHandlerHint = true
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

    private var fileChangedPopover: some View {
        VStack(spacing: 12) {
            Text("There are changes to this file. Would you like to reload?")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("No") {
                    showPopover = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Yes") {
                    try? documentState.reloadFile()
                    showPopover = false
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            Toggle(isOn: Binding(
                get: { appSettings.autoReloadEnabled },
                set: { appSettings.autoReloadEnabled = $0 }
            )) {
                Text("Always reload when unchanged")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
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

    private var updateAvailablePopover: some View {
        VStack(spacing: 12) {
            Text("An update is available.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
