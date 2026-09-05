import AppKit
import SwiftUI

/// Places the now-playing volume control in the titlebar's native right slot.
///
/// Toolbar placements are relative to SwiftUI's sidebar tracking separator and
/// can move to the leading side when that separator changes. A right titlebar
/// accessory has an explicit trailing anchor and is independent of the sidebar.
struct DesktopNowPlayingTrailingAccessoryInstaller: NSViewRepresentable {
    let isPresented: Bool
    let model: DesktopAppModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> DesktopNowPlayingTrailingAccessoryProbe {
        let probe = DesktopNowPlayingTrailingAccessoryProbe()
        probe.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.update(
            isPresented: isPresented,
            model: model
        )
        return probe
    }

    func updateNSView(
        _ nsView: DesktopNowPlayingTrailingAccessoryProbe,
        context: Context
    ) {
        context.coordinator.update(
            isPresented: isPresented,
            model: model
        )
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: DesktopNowPlayingTrailingAccessoryProbe,
        coordinator: Coordinator
    ) {
        nsView.windowDidChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private var isPresented = false
        private var model: DesktopAppModel?
        private var accessoryController: NSTitlebarAccessoryViewController?
        private var hostingView:
            NSHostingView<DesktopNowPlayingTrailingAccessoryContent>?

        init(model: DesktopAppModel) {
            self.model = model
        }

        func update(
            isPresented: Bool,
            model: DesktopAppModel
        ) {
            self.isPresented = isPresented
            self.model = model
            hostingView?.rootView = DesktopNowPlayingTrailingAccessoryContent(
                isPresented: isPresented,
                model: model
            )
            if let hostingView {
                resizeHostingViewToFitContent(hostingView)
            }
            reconcileInstallation()
        }

        func attach(to window: NSWindow?) {
            guard installedWindow !== window else {
                reconcileInstallation()
                return
            }

            detach()
            installedWindow = window
            reconcileInstallation()
        }

        func detach() {
            accessoryController?.removeFromParent()
            accessoryController = nil
            hostingView = nil
            installedWindow = nil
        }

        /// Creates a brand new titlebar accessory on every presentation.
        /// Reusing an `NSTitlebarAccessoryViewController` after
        /// `removeFromParent()` makes AppKit re-layout it with a stale
        /// full-height frame on subsequent opens; a fresh controller always
        /// gets the same first-open vertical placement.
        private func reconcileInstallation() {
            guard let window = installedWindow,
                  let model else { return }

            let currentController = accessoryController
            let isInstalled = currentController.map {
                window.titlebarAccessoryViewControllers.contains($0)
            } ?? false

            if isPresented, !isInstalled {
                currentController?.removeFromParent()

                let hostingView = makeHostingView(
                    isPresented: true,
                    model: model
                )
                let controller = NSTitlebarAccessoryViewController()
                controller.layoutAttribute = .right
                controller.view = hostingView
                window.addTitlebarAccessoryViewController(controller)
                self.hostingView = hostingView
                accessoryController = controller
            } else if !isPresented, isInstalled {
                currentController?.removeFromParent()
                accessoryController = nil
                hostingView = nil
            }
        }

        private func makeHostingView(
            isPresented: Bool,
            model: DesktopAppModel
        ) -> NSHostingView<DesktopNowPlayingTrailingAccessoryContent> {
            let hostingView = NSHostingView(
                rootView: DesktopNowPlayingTrailingAccessoryContent(
                    isPresented: isPresented,
                    model: model
                )
            )
            hostingView.sizingOptions = [.intrinsicContentSize]
            resizeHostingViewToFitContent(hostingView)
            return hostingView
        }

        private func resizeHostingViewToFitContent(
            _ hostingView: NSHostingView<
                DesktopNowPlayingTrailingAccessoryContent
            >
        ) {
            hostingView.invalidateIntrinsicContentSize()
            hostingView.layoutSubtreeIfNeeded()
            let fittingSize = hostingView.fittingSize
            guard fittingSize.width > 0, fittingSize.height > 0 else { return }
            hostingView.setFrameSize(
                NSSize(
                    width: ceil(fittingSize.width),
                    height: ceil(fittingSize.height)
                )
            )
        }
    }
}

final class DesktopNowPlayingTrailingAccessoryProbe: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}

private struct DesktopNowPlayingTrailingAccessoryContent: View {
    let isPresented: Bool
    let model: DesktopAppModel

    var body: some View {
        DesktopNowPlayingVolumeControl()
            .fixedSize(horizontal: true, vertical: true)
            .padding(.trailing, 10)
            .opacity(isPresented ? 1 : 0)
            .allowsHitTesting(isPresented)
            .accessibilityHidden(!isPresented)
            .environment(model)
            .environment(\.colorScheme, .dark)
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}
