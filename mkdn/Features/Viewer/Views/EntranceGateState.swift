#if os(macOS)
    import Foundation

    enum EntranceGateState {
        case idle
        case waiting
        case ready
    }

    @Observable
    @MainActor
    final class EntranceGate {
        var state: EntranceGateState = .idle
        @ObservationIgnored private var timeoutTask: Task<Void, Never>?
        var onReady: (() -> Void)?

        var isGateActive: Bool {
            state == .waiting
        }

        func beginGate() {
            timeoutTask?.cancel()
            state = .waiting
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(AnimationConstants.gateTimeout))
                guard !Task.isCancelled else { return }
                self?.markReady()
            }
        }

        func markReady() {
            guard state == .waiting else { return }
            timeoutTask?.cancel()
            timeoutTask = nil
            state = .ready
            onReady?()
        }

        func reset() {
            timeoutTask?.cancel()
            timeoutTask = nil
            state = .idle
            onReady = nil
        }
    }
#endif
