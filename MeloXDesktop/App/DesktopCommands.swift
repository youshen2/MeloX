import SwiftUI

struct DesktopCommands: Commands {
    let model: DesktopAppModel

    var body: some Commands {
        DesktopSystemCommands()
        DesktopPlaybackCommands(model: model)
        DesktopNavigationCommands(model: model)
    }
}

private struct DesktopSystemCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("ui.desktop.commands.about_melox") { openWindow(id: "about") }
        }

        CommandGroup(replacing: .systemServices) {}
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .toolbar) {}
        CommandGroup(replacing: .sidebar) {}
        CommandGroup(replacing: .windowArrangement) {}
        CommandGroup(replacing: .help) {}
    }
}

private struct DesktopPlaybackCommands: Commands {
    let model: DesktopAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("ui.desktop.commands.controls") {
            Button(model.player.isPlaying ? L10n.string("ui.player.pause") : L10n.string("ui.common.play")) {
                model.player.togglePlayback()
            }
            .keyboardShortcut(
                DesktopPlaybackKeyboardShortcuts.togglePlayback
            )
            .disabled(model.player.currentSong == nil)

            Button("ui.player.previous") {
                Task { await model.player.previous() }
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(model.player.currentSong == nil)

            Button("ui.player.next") {
                Task { await model.player.next() }
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .disabled(model.player.currentSong == nil)

            DesktopPlaybackQualityMenu(model: model)

            Divider()

            Button("ui.player.shuffle") { model.player.toggleShuffle() }
                .keyboardShortcut("s", modifiers: [.command, .option])
            Button("ui.desktop.commands.cycle_repeat") { model.player.cycleRepeatMode() }
                .keyboardShortcut("r", modifiers: [.command, .option])

            Divider()

            Button("ui.desktop.commands.show_lyrics") { model.ui.toggleInspector(.lyrics) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("ui.desktop.commands.show_queue") { model.ui.toggleInspector(.queue) }
                .keyboardShortcut("q", modifiers: [.command, .shift])
            Button("ui.player.now_playing") { model.ui.isNowPlayingPresented = true }
            Button("ui.desktop.mini_player") { openWindow(id: "mini-player") }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("ui.floating_lyrics.title") { openWindow(id: "floating-lyrics") }
        }
    }
}

private struct DesktopNavigationCommands: Commands {
    let model: DesktopAppModel

    var body: some Commands {
        CommandMenu("ui.desktop.commands.navigation") {
            Button("ui.navigation.search") { model.ui.selection = .search }
                .keyboardShortcut("f", modifiers: .command)
            Button("ui.navigation.home") { model.ui.selection = .home }
                .keyboardShortcut("1", modifiers: .command)
            Button("ui.navigation.explore") { model.ui.selection = .discovery }
                .keyboardShortcut("2", modifiers: .command)
            if model.isSectionEnabled(.radio) {
                Button("ui.navigation.podcasts") { model.ui.selection = .radio }
                    .keyboardShortcut("3", modifiers: .command)
            }

            Divider()

            Button("ui.recognition.title") { model.ui.sheet = .recognition }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model.ui.sheet != nil)
        }
    }
}
