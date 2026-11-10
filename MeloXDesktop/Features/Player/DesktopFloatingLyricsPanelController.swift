import AppKit
import SwiftUI

/// A real nonactivating NSPanel is required: the style is not supported on
/// ordinary NSWindows. Dragging and transport controls must not activate MeloX.
@MainActor
final class DesktopFloatingLyricsPanelController: NSObject, NSWindowDelegate {
    static let shared = DesktopFloatingLyricsPanelController()
    private var panel: DesktopFloatingLyricsPanel?
    private var didRestore = false
    private static let visibilityKey = "floatingLyrics.panelVisible"

    func restoreIfNeeded(model: DesktopAppModel, showMain: @escaping () -> Void) {
        guard !didRestore else { return }
        didRestore = true
        let defaults = UserDefaults.standard
        let wasVisible = defaults.object(forKey: Self.visibilityKey) as? Bool
            ?? (defaults.string(forKey: "NSWindow Frame floating-lyrics") != nil)
        if wasVisible { show(model: model, showMain: showMain) }
    }

    func show(model: DesktopAppModel, showMain: @escaping () -> Void) {
        if let panel {
            panel.orderFrontRegardless()
            UserDefaults.standard.set(true, forKey: Self.visibilityKey)
            return
        }
        let panel = DesktopFloatingLyricsPanel(
            contentRect: NSRect(x: 0, y: 0,
                width: DesktopFloatingLyricsWindowMetrics.defaultWidth,
                height: DesktopFloatingLyricsWindowMetrics.defaultHeight),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered, defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("floating-lyrics")
        panel.title = L10n.string("ui.floating_lyrics.title")
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.delegate = self
        panel.center()
        self.panel = panel
        panel.contentView = NSHostingView(rootView:
            DesktopFloatingLyricsPanelContent(model: model,
                showMain: showMain, close: { [weak self] in self?.panel?.close() })
        )
        panel.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: Self.visibilityKey)
    }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: Self.visibilityKey)
        // Keep the hosting view and saved frame for the next explicit opening.
    }
}

private final class DesktopFloatingLyricsPanel: NSPanel {
    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { true }
}

private struct DesktopFloatingLyricsPanelContent: View {
    let model: DesktopAppModel
    let showMain: () -> Void
    let close: () -> Void

    var body: some View {
        DesktopFloatingLyricsWindow(showMainWindow: showMain, closeWindow: close)
            .environment(model)
            .environment(\.locale, model.settings.appLanguage.locale)
            .preferredColorScheme(model.settings.appearance.preferredColorScheme)
            .tint(.red)
    }
}
