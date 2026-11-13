import SwiftUI

/// Reverted to the previous-commit progress rollover: direct hover-driven
/// expansion with the pressed-scale seek bar. The newer MusicLCDToolbar
/// state-machine variant made the expansion feel slow and was removed per
/// user request.
struct DesktopBottomMetadataSlot: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let song: Song
    let openNowPlaying: () -> Void
    @State private var isProgressExpanded = false
    @State private var isArtworkHovered = false
    @GestureState private var isProgressPressed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            metadataContent
                .blur(radius: isProgressExpanded ? 7 : 0)
                .allowsHitTesting(!isProgressExpanded)

            progressOverlay
        }
        .frame(height: DesktopBottomPlayerMetrics.outerHeight)
        .contentShape(.rect)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isProgressPressed) { _, pressed, _ in
                    guard isProgressExpanded else { return }
                    pressed = true
                }
        )
        .animation(
            reduceMotion ? nil : DesktopPlayerMotion.progressPress,
            value: isProgressPressed
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                if isProgressExpanded
                    || (!isArtworkHovered && location.y >= 38) {
                    setProgressExpanded(true)
                }
            case .ended:
                setProgressExpanded(false)
            }
        }
        .onDisappear {
            model.ui.isPlayerProgressHovered = false
        }
    }

    private var metadataContent: some View {
        HStack(spacing: 4) {
            Button(action: openNowPlaying) {
                HStack(spacing: 9) {
                    artwork

                    VStack(alignment: .leading, spacing: 1) {
                        Text(song.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)
                        Text(
                            L10n.joined(
                                [song.artistText, song.album?.name ?? ""],
                                separatorKey:
                                    "ui.common.title_detail_separator"
                            )
                        )
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            playerMenu
        }
    }

    private var progressOverlay: some View {
        VStack(spacing: 4) {
            if isProgressExpanded {
                HStack {
                    Text(format(model.player.progress))
                    Spacer()
                    Text(
                        "−\(format(max(model.player.duration - model.player.progress, 0)))"
                    )
                }
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.primary)
                .frame(height: 15)
                .transition(
                    .blurReplace.combined(
                        with: .scale(0.94, anchor: .bottom)
                    )
                )
            }

            DesktopBottomSeekBar(
                isExpanded: isProgressExpanded,
                isPressed: isProgressPressed
            )
            .frame(height: 14)
            .contentShape(.rect)
        }
        .padding(.bottom, 1)
        .scaleEffect(
            x: isProgressPressed
                ? 1.022
                : isProgressExpanded
                    ? 1
                    : DesktopBottomProgressMetrics
                        .collapsedProgressHorizontalScale,
            y: isProgressPressed ? 1.06 : 1,
            anchor: .bottom
        )
    }

    private var artwork: some View {
        ZStack {
            DesktopArtworkView(
                url: song.album?.artworkURL,
                cornerRadius: 6
            )

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.black.opacity(isArtworkHovered ? 0.32 : 0))

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.36), radius: 2, y: 1)
                .opacity(isArtworkHovered ? 1 : 0)
                .blur(radius: isArtworkHovered ? 0 : 1.8)
                .scaleEffect(isArtworkHovered ? 1 : 0.62)
        }
        .frame(width: 36, height: 36)
        .scaleEffect(isArtworkHovered ? 1.18 : 1)
        .shadow(
            color: .black.opacity(isArtworkHovered ? 0.26 : 0),
            radius: isArtworkHovered ? 8 : 0,
            y: isArtworkHovered ? 4 : 0
        )
        .zIndex(2)
        .onHover(perform: setArtworkHovered)
        .accessibilityAddTraits(.isButton)
    }

    private var playerMenu: some View {
        Menu {
            Picker(
                "ui.settings.lyrics.content.default_source",
                selection: Binding(
                    get: { model.settings.lyricsSourcePreference },
                    set: { model.settings.lyricsSourcePreference = $0 }
                )
            ) {
                ForEach(LyricSourcePreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }

            Divider()
            Button(
                model.library.contains(song: song)
                    ? L10n.string("ui.song.unlike")
                    : L10n.string("ui.song.like"),
                systemImage: model.library.contains(song: song)
                    ? "star.fill"
                    : "star"
            ) {
                model.library.toggle(song: song)
            }
            if model.settings.isContentFeatureEnabled(.downloads) {
                Button("ui.common.download", systemImage: "arrow.down.circle") {
                    model.downloads.start(song, quality: model.settings.quality)
                }
            }
            Button("ui.song.view_information", systemImage: "arrow.right.circle") {
                model.ui.navigate(to: .song(song.id))
            }
            Button("ui.common.lyrics", systemImage: "quote.bubble") {
                model.ui.toggleInspector(.lyrics)
            }
            Button("ui.player.queue", systemImage: "list.bullet") {
                model.ui.toggleInspector(.queue)
            }
            DesktopPlaybackQualityMenu(model: model)
            Divider()
            Button("ui.desktop.mini_player", systemImage: "pip") {
                Task { @MainActor in
                    openWindow(id: "mini-player")
                    await DesktopMiniPlayerWindowCoordinator
                        .bringToFrontAfterOpening()
                }
            }
            Button(
                "ui.desktop.player.fullscreen_now_playing",
                systemImage: "arrow.up.left.and.arrow.down.right"
            ) {
                model.ui.isNowPlayingPresented = true
            }
            Button("ui.floating_lyrics.title", systemImage: "text.quote") {
                DesktopFloatingLyricsPanelController.shared.show(model: model) {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
            }
            if let url = URL(
                string: "https://music.163.com/#/song?id=\(song.id)"
            ) {
                ShareLink(item: url) {
                    Label("ui.common.share", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func setArtworkHovered(_ hovered: Bool) {
        guard isArtworkHovered != hovered else { return }
        withAnimation(
            reduceMotion
                ? nil
                : hovered
                    ? DesktopPlayerMotion.artworkHover
                    : DesktopPlayerMotion.artworkRest
        ) {
            isArtworkHovered = hovered
        }
    }

    private func setProgressExpanded(_ expanded: Bool) {
        guard isProgressExpanded != expanded else { return }
        withAnimation(
            reduceMotion
                ? nil
                : DesktopPlayerMotion.progress(expanded: expanded)
        ) {
            isProgressExpanded = expanded
            model.ui.isPlayerProgressHovered = expanded
        }
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        let seconds = max(Int(time), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
