import AppKit
import SwiftUI

enum DesktopMainWindowMetrics {
    static let minimumContentWidth: CGFloat = 980
    static let minimumContentHeight: CGFloat = 540
    /// Music 1.6.6 grows the ordinary window by exactly 258 points before
    /// mounting the lyrics/up-next inspector.
    static let playerSidePanelWidth: CGFloat = 258
    static let presentationDuration: TimeInterval = 0.28
    static let presentationAnimation: Animation = .easeInOut(
        duration: presentationDuration
    )

    static func minimumContentWidth(
        isPlayerSidePanelPresented: Bool
    ) -> CGFloat {
        minimumContentWidth
            + (isPlayerSidePanelPresented ? playerSidePanelWidth : 0)
    }
}

/// Keeps the main page width stable while the player side panel is presented.
///
/// SwiftUI's inspector consumes space inside the current window. Apple Music
/// instead grows its window first, then presents the panel in the newly added
/// trailing area. The probe coordinates the native window frame and reports
/// full-screen transitions; the panel and its background remain SwiftUI-owned.
struct DesktopMainWindowConfiguration: NSViewRepresentable {
    let isPlayerSidePanelPresented: Bool
    @Binding var isFullScreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullScreen: $isFullScreen)
    }

    func makeNSView(context: Context) -> DesktopMainWindowProbe {
        let probe = DesktopMainWindowProbe()
        probe.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.update(
            isPlayerSidePanelPresented: isPlayerSidePanelPresented
        )
        return probe
    }

    func updateNSView(
        _ nsView: DesktopMainWindowProbe,
        context: Context
    ) {
        context.coordinator.update(
            isPlayerSidePanelPresented: isPlayerSidePanelPresented
        )
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: DesktopMainWindowProbe,
        coordinator: Coordinator
    ) {
        nsView.windowDidChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private var requestedPresentation = false
        private var appliedPresentation = false
        private var presentationFrameAdjustment: FrameAdjustment?
        private var isApplyingPresentationChange = false
        private var isFullScreen: Binding<Bool>
        private var fullScreenObservers: [NSObjectProtocol] = []

        init(isFullScreen: Binding<Bool>) {
            self.isFullScreen = isFullScreen
        }

        func update(
            isPlayerSidePanelPresented: Bool
        ) {
            requestedPresentation = isPlayerSidePanelPresented
            applyPresentationChangeIfNeeded()
        }

        func attach(to window: NSWindow?) {
            guard installedWindow !== window else {
                applyPresentationChangeIfNeeded()
                return
            }

            detach()
            installedWindow = window
            observeFullScreenChanges()
            applyPresentationChangeIfNeeded()
            applyMinimumContentSize()
        }

        func detach() {
            for observer in fullScreenObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            fullScreenObservers.removeAll()
            installedWindow = nil
            appliedPresentation = false
            presentationFrameAdjustment = nil
        }

        private func observeFullScreenChanges() {
            guard let window = installedWindow else { return }
            fullScreenObservers = [
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
            ].map { name in
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.publishFullScreenState()
                    }
                }
            }
            publishFullScreenState()
        }

        private func publishFullScreenState() {
            // The initial attachment can occur inside a SwiftUI view update.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isFullScreen.wrappedValue =
                    self.installedWindow?.styleMask.contains(.fullScreen) == true
            }
        }

        private func applyPresentationChangeIfNeeded() {
            guard let window = installedWindow else { return }
            guard !isApplyingPresentationChange else { return }

            isApplyingPresentationChange = true
            defer { isApplyingPresentationChange = false }

            guard appliedPresentation != requestedPresentation else {
                if !requestedPresentation {
                    contractIfNeeded(window)
                }
                applyMinimumContentSize()
                return
            }

            let wasPresented = appliedPresentation
            // `setFrame` performs layout synchronously. Commit the logical
            // state first so a reentrant SwiftUI update cannot apply the same
            // expansion or contraction for a second time.
            appliedPresentation = requestedPresentation

            if requestedPresentation {
                expandIfNeeded(window)
            } else if wasPresented {
                // Release the expanded minimum before removing the width
                // that was added for the panel.
                applyMinimumContentSize()
                contractIfNeeded(window)
            }
            applyMinimumContentSize()
        }

        private func expandIfNeeded(_ window: NSWindow) {
            let initialFrame = window.frame

            guard !window.styleMask.contains(.fullScreen) else { return }

            var targetFrame = initialFrame
            let requestedWidth = initialFrame.width
                + DesktopMainWindowMetrics.playerSidePanelWidth

            if let visibleFrame = window.screen?.visibleFrame {
                targetFrame.size.width = min(
                    requestedWidth,
                    max(initialFrame.width, visibleFrame.width)
                )

                if targetFrame.maxX > visibleFrame.maxX {
                    targetFrame.origin.x -= targetFrame.maxX
                        - visibleFrame.maxX
                }
                targetFrame.origin.x = max(
                    targetFrame.origin.x,
                    visibleFrame.minX
                )
            } else {
                targetFrame.size.width = requestedWidth
            }

            presentationFrameAdjustment = FrameAdjustment(
                originX: targetFrame.origin.x - initialFrame.origin.x,
                width: targetFrame.width - initialFrame.width
            )
            setFrame(targetFrame, on: window)
        }

        private func contractIfNeeded(_ window: NSWindow) {
            guard let adjustment = presentationFrameAdjustment else { return }
            guard !window.styleMask.contains(.fullScreen) else { return }

            var targetFrame = window.frame
            targetFrame.origin.x -= adjustment.originX
            targetFrame.size.width -= adjustment.width

            let minimumContentRect = NSRect(
                origin: .zero,
                size: NSSize(
                    width: DesktopMainWindowMetrics.minimumContentWidth,
                    height: DesktopMainWindowMetrics.minimumContentHeight
                )
            )
            let minimumFrameWidth = window.frameRect(
                forContentRect: minimumContentRect
            ).width
            targetFrame.size.width = max(
                targetFrame.width,
                minimumFrameWidth
            )

            // Clear the adjustment before `setFrame` starts a synchronous
            // layout pass. This prevents the collapsed frame from being
            // treated as another pending contraction during reentry.
            presentationFrameAdjustment = nil
            setFrame(targetFrame, on: window)
        }

        private func applyMinimumContentSize() {
            guard let window = installedWindow else { return }

            let requestedWidth = DesktopMainWindowMetrics.minimumContentWidth(
                isPlayerSidePanelPresented: requestedPresentation
            )
            let availableWidth = window.screen.map { screen in
                window.contentRect(forFrameRect: screen.visibleFrame).width
            }
            let minimumWidth = min(
                requestedWidth,
                max(
                    DesktopMainWindowMetrics.minimumContentWidth,
                    availableWidth ?? requestedWidth
                )
            )

            let minimumContentSize = NSSize(
                width: minimumWidth,
                height: DesktopMainWindowMetrics.minimumContentHeight
            )
            guard window.contentMinSize != minimumContentSize else { return }
            window.contentMinSize = minimumContentSize
        }

        private func setFrame(_ frame: NSRect, on window: NSWindow) {
            guard frame != window.frame else { return }
            window.setFrame(frame, display: true)
        }

        private struct FrameAdjustment {
            let originX: CGFloat
            let width: CGFloat
        }

    }
}

final class DesktopMainWindowProbe: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}
