import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ScreenAwakeCoordinator {
    @ObservationIgnored
    private var activeRequests: Set<UUID> = []

    func setKeepsScreenAwake(_ keepsScreenAwake: Bool, for requestID: UUID) {
        let requestChanged: Bool

        if keepsScreenAwake {
            requestChanged = activeRequests.insert(requestID).inserted
        } else {
            requestChanged = activeRequests.remove(requestID) != nil
        }

        guard requestChanged else { return }
        UIApplication.shared.isIdleTimerDisabled = !activeRequests.isEmpty
    }
}

extension View {
    func keepsScreenAwake(_ isEnabled: Bool) -> some View {
        modifier(KeepsScreenAwakeModifier(isEnabled: isEnabled))
    }
}

private struct KeepsScreenAwakeModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ScreenAwakeCoordinator.self) private var coordinator

    let isEnabled: Bool

    @State private var requestID = UUID()
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                updateRequest()
            }
            .onDisappear {
                isVisible = false
                coordinator.setKeepsScreenAwake(false, for: requestID)
            }
            .onChange(of: isEnabled) { _, _ in
                updateRequest()
            }
            .onChange(of: scenePhase) { _, _ in
                updateRequest()
            }
    }

    private func updateRequest() {
        coordinator.setKeepsScreenAwake(
            isEnabled && isVisible && scenePhase == .active,
            for: requestID
        )
    }
}
