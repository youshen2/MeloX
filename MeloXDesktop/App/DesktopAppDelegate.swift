import AppKit

@MainActor
final class DesktopAppDelegate: NSObject, NSApplicationDelegate {
    let model = DesktopAppModel()

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let hasCurrentSong = model.player.currentSong != nil
        menu.addItem(
            menuItem(
                title: L10n.string(
                    model.player.isPlaying
                        ? "ui.player.pause"
                        : "ui.common.play"
                ),
                action: #selector(togglePlayback),
                isEnabled: hasCurrentSong
            )
        )
        menu.addItem(
            menuItem(
                title: L10n.string("ui.player.next"),
                action: #selector(playNext),
                isEnabled: hasCurrentSong
            )
        )
        menu.addItem(
            menuItem(
                title: L10n.string("ui.player.previous"),
                action: #selector(playPrevious),
                isEnabled: hasCurrentSong
            )
        )

        let currentSongIsLiked = model.player.currentSong.map {
            model.library.contains(song: $0)
        } == true
        menu.addItem(
            menuItem(
                title: L10n.string(
                    currentSongIsLiked
                        ? "ui.song.unlike"
                        : "ui.song.like"
                ),
                action: #selector(toggleCurrentSongLike),
                isEnabled: hasCurrentSong
            )
        )

        menu.addItem(repeatMenuItem(isEnabled: hasCurrentSong))

        let shuffleItem = menuItem(
            title: L10n.string("ui.player.shuffle"),
            action: #selector(toggleShuffle),
            isEnabled:
                hasCurrentSong
                && !model.player.isListenTogetherSessionActive
        )
        shuffleItem.state = model.player.isShuffled ? .on : .off
        menu.addItem(shuffleItem)

        return menu
    }

    private func repeatMenuItem(isEnabled: Bool) -> NSMenuItem {
        let title = L10n.string("ui.player.repeat")
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled =
            isEnabled && !model.player.isListenTogetherSessionActive

        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        for mode in RepeatMode.allCases {
            let modeItem = menuItem(
                title: mode.accessibilityTitle,
                action: #selector(selectRepeatMode),
                isEnabled: item.isEnabled
            )
            modeItem.representedObject = mode.rawValue
            modeItem.state = model.player.repeatMode == mode ? .on : .off
            submenu.addItem(modeItem)
        }
        item.submenu = submenu
        return item
    }

    private func menuItem(
        title: String,
        action: Selector,
        isEnabled: Bool
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = isEnabled
        return item
    }

    @objc private func togglePlayback() {
        model.player.togglePlayback()
    }

    @objc private func playNext() {
        Task { await model.player.next() }
    }

    @objc private func playPrevious() {
        Task { await model.player.previous() }
    }

    @objc private func toggleCurrentSongLike() {
        guard let song = model.player.currentSong else { return }
        model.library.toggle(song: song)
    }

    @objc private func selectRepeatMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = RepeatMode(rawValue: rawValue) else {
            return
        }
        model.player.setRepeatMode(mode)
    }

    @objc private func toggleShuffle() {
        model.player.toggleShuffle()
    }
}
