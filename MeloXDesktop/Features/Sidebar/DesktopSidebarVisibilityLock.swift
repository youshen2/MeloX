import AppKit
import SwiftUI

/// Keeps the native sidebar-backed `TabView` permanently visible.
///
/// SwiftUI can remove its standard toolbar item, but it does not expose the
/// AppKit flags that prevent a macOS sidebar from being collapsed by dragging
/// its divider or by resizing the window. The account footer is hosted inside
/// that sidebar column so it tracks the divider while it is dragged.
struct DesktopSidebarVisibilityLock<Footer: View>: NSViewRepresentable {
    var reservedBottomInset: CGFloat
    var footer: Footer

    func makeCoordinator() -> Coordinator {
        Coordinator(
            reservedBottomInset: reservedBottomInset,
            footer: footer
        )
    }

    func makeNSView(context: Context) -> DesktopSidebarVisibilityProbe {
        let probe = DesktopSidebarVisibilityProbe()
        probe.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return probe
    }

    func updateNSView(
        _ nsView: DesktopSidebarVisibilityProbe,
        context: Context
    ) {
        context.coordinator.reservedBottomInset = reservedBottomInset
        context.coordinator.footerHost.update(rootView: footer)
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: DesktopSidebarVisibilityProbe,
        coordinator: Coordinator
    ) {
        nsView.windowDidChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private weak var installedSidebarItem: NSSplitViewItem?
        private weak var installedSplitViewController: NSSplitViewController?
        private weak var installedSidebarScrollView: NSScrollView?
        private var windowUpdateObserver: NSObjectProtocol?
        private var deferredConfigurationTask: Task<Void, Never>?
        private var originalBottomContentInset: CGFloat?
        fileprivate let footerHost: SidebarFooterHost<Footer>
        var reservedBottomInset: CGFloat

        init(
            reservedBottomInset: CGFloat,
            footer: Footer
        ) {
            self.reservedBottomInset = reservedBottomInset
            footerHost = SidebarFooterHost(rootView: footer)
        }

        func attach(to window: NSWindow?) {
            guard installedWindow !== window else {
                configureWindow()
                return
            }

            detach()
            installedWindow = window

            guard let window else { return }
            windowUpdateObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.configureWindow()
                }
            }

            configureWindow()
            deferredConfigurationTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled else { return }
                self?.configureWindow()
            }
        }

        func detach() {
            deferredConfigurationTask?.cancel()
            deferredConfigurationTask = nil

            if let windowUpdateObserver {
                NotificationCenter.default.removeObserver(windowUpdateObserver)
            }
            windowUpdateObserver = nil
            restoreOriginalBottomContentInset()
            footerHost.removeFromSuperview()
            installedSidebarItem = nil
            installedSplitViewController = nil
            installedSidebarScrollView = nil
            installedWindow = nil
            originalBottomContentInset = nil
        }

        private func configureWindow() {
            guard let window = installedWindow else { return }
            removeSidebarToggle(from: window.toolbar)

            if let installedSidebarItem,
               let installedSplitViewController,
               installedSidebarItem.viewController.view.window === window {
                lock(installedSidebarItem, in: installedSplitViewController)
                return
            }
            installedSidebarItem = nil
            installedSplitViewController = nil

            var configuredControllers = Set<ObjectIdentifier>()
            if let rootViewController = window.contentViewController {
                lockSidebarItems(
                    below: rootViewController,
                    configuredControllers: &configuredControllers
                )
            }
            if let contentView = window.contentView {
                lockSidebarItems(
                    below: contentView,
                    configuredControllers: &configuredControllers
                )
            }
        }

        private func removeSidebarToggle(from toolbar: NSToolbar?) {
            guard let toolbar else { return }

            let indexes = toolbar.items.indices.filter { index in
                let identifier = toolbar.items[index].itemIdentifier
                if identifier == .toggleSidebar {
                    return true
                }

                let rawIdentifier = identifier.rawValue.lowercased()
                return rawIdentifier.contains("sidebar")
                    && rawIdentifier.contains("toggle")
            }

            for index in indexes.reversed() {
                toolbar.removeItem(at: index)
            }
        }

        private func lockSidebarItems(
            below viewController: NSViewController,
            configuredControllers: inout Set<ObjectIdentifier>
        ) {
            if let splitViewController = viewController as? NSSplitViewController {
                lockSidebarItems(
                    in: splitViewController,
                    configuredControllers: &configuredControllers
                )
            }

            for child in viewController.children {
                lockSidebarItems(
                    below: child,
                    configuredControllers: &configuredControllers
                )
            }
        }

        private func lockSidebarItems(
            below view: NSView,
            configuredControllers: inout Set<ObjectIdentifier>
        ) {
            if let splitView = view as? NSSplitView,
               let splitViewController = splitView.delegate
                as? NSSplitViewController {
                lockSidebarItems(
                    in: splitViewController,
                    configuredControllers: &configuredControllers
                )
            }

            for subview in view.subviews {
                lockSidebarItems(
                    below: subview,
                    configuredControllers: &configuredControllers
                )
            }
        }

        private func lockSidebarItems(
            in splitViewController: NSSplitViewController,
            configuredControllers: inout Set<ObjectIdentifier>
        ) {
            let identifier = ObjectIdentifier(splitViewController)
            guard configuredControllers.insert(identifier).inserted else {
                return
            }

            for item in splitViewController.splitViewItems
            where item.behavior == .sidebar {
                installedSidebarItem = item
                installedSplitViewController = splitViewController
                lock(item, in: splitViewController)
            }
        }

        private func lock(
            _ item: NSSplitViewItem,
            in splitViewController: NSSplitViewController
        ) {
            if item.isCollapsed {
                item.isCollapsed = false
            }
            if item.canCollapse {
                item.canCollapse = false
            }
            if item.canCollapseFromWindowResize {
                item.canCollapseFromWindowResize = false
            }
            if item.isSpringLoaded {
                item.isSpringLoaded = false
            }

            let maximumWidth = DesktopMainWindowMetrics.maximumSidebarWidth
            if item.maximumThickness != maximumWidth {
                item.maximumThickness = maximumWidth
            }
            let sidebarWidth = item.viewController.view.bounds.width
            if sidebarWidth > maximumWidth + 0.5 {
                let dividerIndex = splitViewController.splitViewItems
                    .firstIndex(of: item) ?? 0
                splitViewController.splitView.setPosition(
                    maximumWidth,
                    ofDividerAt: dividerIndex
                )
            }

            let sidebarView = item.viewController.view
            reserveFooterSpace(below: sidebarView)
            footerHost.place(
                in: sidebarView,
                height: reservedBottomInset
            )
        }

        private func reserveFooterSpace(below view: NSView) {
            guard let scrollView = firstScrollView(below: view) else { return }

            if installedSidebarScrollView !== scrollView {
                restoreOriginalBottomContentInset()
                installedSidebarScrollView = scrollView
                originalBottomContentInset = scrollView.contentInsets.bottom
            }

            var contentInsets = scrollView.contentInsets
            contentInsets.bottom = (originalBottomContentInset ?? 0)
                + reservedBottomInset
            guard abs(scrollView.contentInsets.bottom - contentInsets.bottom)
                > .ulpOfOne else {
                return
            }
            scrollView.contentInsets = contentInsets
        }

        private func firstScrollView(below view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }

            for subview in view.subviews {
                if let scrollView = firstScrollView(below: subview) {
                    return scrollView
                }
            }
            return nil
        }

        private func restoreOriginalBottomContentInset() {
            guard let scrollView = installedSidebarScrollView,
                  let originalBottomContentInset else {
                return
            }

            var contentInsets = scrollView.contentInsets
            contentInsets.bottom = originalBottomContentInset
            scrollView.contentInsets = contentInsets
        }

    }
}

fileprivate final class SidebarFooterHost<Footer: View>: NSView {
    let hostingView: NSHostingView<Footer>

    init(rootView: Footer) {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        self.hostingView = hostingView
        super.init(frame: .zero)
        addSubview(hostingView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        hostingView.frame = bounds
    }

    func update(rootView: Footer) {
        hostingView.rootView = rootView
    }

    func place(in sidebarView: NSView, height: CGFloat) {
        guard let container = footerContainer(above: sidebarView) else { return }

        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = container.isFlipped
            ? [.width, .minYMargin]
            : [.width, .maxYMargin]

        let anchor = sidebarView.superview === container ? sidebarView : nil
        if superview !== container {
            removeFromSuperview()
            container.addSubview(self, positioned: .above, relativeTo: anchor)
        } else if container.subviews.last !== self {
            container.addSubview(self, positioned: .above, relativeTo: anchor)
        }

        let sidebarFrame = sidebarView.convert(sidebarView.bounds, to: container)
        let originY = container.isFlipped
            ? sidebarFrame.maxY - height
            : sidebarFrame.minY
        let nextFrame = NSRect(
            x: sidebarFrame.minX,
            y: originY,
            width: sidebarFrame.width,
            height: height
        )
        guard frame != nextFrame else { return }
        frame = nextFrame
    }

    /// `NSHostingView` rejects AppKit subviews. The footer sits in the first
    /// ordinary ancestor so it stays in the sidebar column without becoming
    /// part of the hosting view.
    private func footerContainer(above sidebarView: NSView) -> NSView? {
        var container = sidebarView
        while Self.isHostingView(container) {
            guard let parent = container.superview else { return nil }
            container = parent
        }
        return container
    }

    private static func isHostingView(_ view: NSView) -> Bool {
        String(describing: type(of: view)).contains("HostingView")
    }
}

final class DesktopSidebarVisibilityProbe: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}
