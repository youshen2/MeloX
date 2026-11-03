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
        private weak var observedToolbar: NSToolbar?
        private var windowUpdateObserver: NSObjectProtocol?
        private var toolbarItemObservers: [NSObjectProtocol] = []
        private var toolbarObservation: NSKeyValueObservation?
        private var deferredConfigurationTask: Task<Void, Never>?
        private var originalBottomContentInset: CGFloat?
        private var isSuppressingSidebarToggle = false
        private var isSidebarToggleRemovalScheduled = false
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
            toolbarObservation = window.observe(\.toolbar, options: [.initial, .new]) { [weak self] window, _ in
                MainActor.assumeIsolated {
                    self?.toolbarDidChange(window.toolbar)
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
            stopObservingToolbar()
            isSidebarToggleRemovalScheduled = false
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
            observeToolbar(window.toolbar)
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

        /// SwiftUI can replace the window toolbar while switching tabs. Follow
        /// the live instance so the toggle is hidden before the next display.
        private func toolbarDidChange(_ toolbar: NSToolbar?) {
            observeToolbar(toolbar)
            removeSidebarToggle(from: toolbar)
        }

        private func observeToolbar(_ toolbar: NSToolbar?) {
            guard observedToolbar !== toolbar else { return }
            stopObservingToolbarItems()
            observedToolbar = toolbar
            guard let toolbar else { return }

            toolbarItemObservers = [
                NotificationCenter.default.addObserver(
                    forName: NSToolbar.willAddItemNotification,
                    object: toolbar,
                    queue: .main
                ) { [weak self] notification in
                    MainActor.assumeIsolated {
                        self?.toolbarWillAddItem(notification)
                    }
                }
            ]
        }

        private func stopObservingToolbar() {
            toolbarObservation?.invalidate()
            toolbarObservation = nil
            stopObservingToolbarItems()
            observedToolbar = nil
        }

        private func stopObservingToolbarItems() {
            for observer in toolbarItemObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            toolbarItemObservers.removeAll()
        }

        /// AppKit posts this before the item is inserted and has no matching
        /// did-add notification. Hide first so a synchronous display cannot
        /// paint the button, then remove it before the run loop waits.
        private func toolbarWillAddItem(_ notification: Notification) {
            guard let toolbar = notification.object as? NSToolbar,
                  toolbar === installedWindow?.toolbar,
                  let item = notification.userInfo?[NSToolbarUserInfoKey.itemKey] as? NSToolbarItem,
                  Self.isSidebarToggle(item) else {
                return
            }

            item.isHidden = true
            scheduleSidebarToggleRemoval(from: toolbar)
        }

        private func scheduleSidebarToggleRemoval(from toolbar: NSToolbar) {
            guard !isSidebarToggleRemovalScheduled else { return }
            isSidebarToggleRemovalScheduled = true
            CFRunLoopPerformBlock(
                CFRunLoopGetMain(),
                CFRunLoopMode.commonModes.rawValue
            ) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.removeSidebarToggle(from: toolbar)
                    self.isSidebarToggleRemovalScheduled = false
                }
            }
            CFRunLoopWakeUp(CFRunLoopGetMain())
        }

        private func removeSidebarToggle(from toolbar: NSToolbar?) {
            guard let toolbar, !isSuppressingSidebarToggle else { return }

            let indexes = toolbar.items.indices.filter { index in
                Self.isSidebarToggle(toolbar.items[index])
            }
            guard !indexes.isEmpty else { return }

            isSuppressingSidebarToggle = true
            defer { isSuppressingSidebarToggle = false }
            for index in indexes.reversed() {
                toolbar.items[index].isHidden = true
                toolbar.removeItem(at: index)
            }
        }

        private static func isSidebarToggle(_ item: NSToolbarItem) -> Bool {
            let identifier = item.itemIdentifier
            if identifier == .toggleSidebar {
                return true
            }

            let rawIdentifier = identifier.rawValue.lowercased()
            return rawIdentifier.contains("sidebar")
                && rawIdentifier.contains("toggle")
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
