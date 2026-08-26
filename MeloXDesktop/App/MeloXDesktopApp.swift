import AppKit
import SwiftUI

@main
struct MeloXDesktopApp: App {
    @NSApplicationDelegateAdaptor(DesktopAppDelegate.self)
    private var appDelegate

    private var model: DesktopAppModel {
        appDelegate.model
    }

    init() {
        // MeloX 的各播放器窗口用途不同，不应被系统合并为标签页。
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup("MeloX") {
            DesktopRootView()
                .environment(model)
                .environment(model.screenAwakeCoordinator)
                .environment(\.locale, model.settings.appLanguage.locale)
                .preferredColorScheme(
                    model.settings.appearance.preferredColorScheme
                )
                .frame(
                    minWidth: DesktopMainWindowMetrics.minimumContentWidth,
                    minHeight: DesktopMainWindowMetrics.minimumContentHeight
                )
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowToolbarLabelStyle(fixed: .iconOnly)
        .defaultSize(width: 1_272, height: 600)
        .commands {
            DesktopCommands(model: model)
        }

        Window("ui.desktop.mini_player", id: "mini-player") {
            DesktopMiniPlayerWindow()
                .environment(model)
                .environment(\.locale, model.settings.appLanguage.locale)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.disabled)
        .defaultSize(width: 320, height: 145)

        Window("ui.floating_lyrics.title", id: "floating-lyrics") {
            DesktopFloatingLyricsWindow()
                .environment(model)
                .environment(\.locale, model.settings.appLanguage.locale)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
        .windowStyle(.plain)
        .windowLevel(.floating)
        .windowResizability(.contentMinSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(
            width: DesktopFloatingLyricsWindowMetrics.defaultWidth,
            height: DesktopFloatingLyricsWindowMetrics.defaultHeight
        )

        Window("ui.desktop.commands.about_melox", id: "about") {
            DesktopAboutView()
                .environment(\.locale, model.settings.appLanguage.locale)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 600, height: 320)
        .defaultPosition(.center)

        Window("ui.legal.projects_licenses.title", id: "licenses") {
            NavigationStack {
                DesktopProjectLicensesView()
            }
            .environment(\.locale, model.settings.appLanguage.locale)
            .preferredColorScheme(model.settings.appearance.preferredColorScheme)
            .frame(width: 680, height: 680)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 680, height: 680)

        Settings {
            DesktopSettingsView()
                .environment(model)
                .environment(\.locale, model.settings.appLanguage.locale)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 650, height: 650)
    }
}
