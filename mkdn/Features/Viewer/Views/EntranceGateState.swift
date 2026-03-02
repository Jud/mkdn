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
        @ObservationIgnored private var minDurationTask: Task<Void, Never>?
        @ObservationIgnored private var contentReady = false
        @ObservationIgnored private var minDurationElapsed = false
        var onReady: (() -> Void)?

        /// Minimum time the gate stays active so the orb has at least one
        /// SwiftUI render pass and the transition doesn't feel like a flash.
        private static let minimumGateDuration: TimeInterval = 0.4

        var isGateActive: Bool {
            state == .waiting
        }

        func beginGate() {
            timeoutTask?.cancel()
            minDurationTask?.cancel()
            contentReady = false
            minDurationElapsed = false
            state = .waiting

            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(AnimationConstants.gateTimeout))
                guard !Task.isCancelled else { return }
                self?.dismissGate()
            }
            minDurationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.minimumGateDuration))
                guard !Task.isCancelled else { return }
                guard let self else { return }
                minDurationElapsed = true
                if contentReady {
                    dismissGate()
                }
            }
        }

        func markReady() {
            guard state == .waiting else { return }
            contentReady = true
            if minDurationElapsed {
                dismissGate()
            }
        }

        private func dismissGate() {
            guard state == .waiting else { return }
            timeoutTask?.cancel()
            minDurationTask?.cancel()
            timeoutTask = nil
            minDurationTask = nil
            state = .ready
            onReady?()
        }

        func reset() {
            timeoutTask?.cancel()
            minDurationTask?.cancel()
            timeoutTask = nil
            minDurationTask = nil
            contentReady = false
            minDurationElapsed = false
            state = .idle
            onReady = nil
        }
    }
#endif
