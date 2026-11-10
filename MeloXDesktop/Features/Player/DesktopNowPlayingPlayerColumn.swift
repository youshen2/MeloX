import SwiftUI

struct DesktopNowPlayingPlayerColumn: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    let layout: DesktopNowPlayingLayout
    let tint: Color
    let isActive: Bool

    var body: some View {
        let elementScale = layout.elementScale

        VStack(alignment: .leading, spacing: 0) {
            DesktopNowPlayingArtwork(
                artworkURL: model.player.currentSong?.album?.artworkURL,
                songName: model.player.currentSong?.name,
                pausedSize: layout.artworkSize,
                isPlaying: model.player.isPlaying,
                shrinksWhenPaused: model.settings.shrinksPausedArtwork
            )
            .frame(maxWidth: .infinity)
            .padding(.top, layout.artworkTopInset)

            HStack(alignment: .bottom, spacing: 10 * elementScale) {
                metadata(elementScale: elementScale)

                Spacer(minLength: 6 * elementScale)

                favoriteButton(elementScale: elementScale)
                playerMenu(elementScale: elementScale)
            }
            .padding(.top, layout.metadataTopInset)

            DesktopNowPlayingProgress(
                tint: tint,
                isActive: isActive,
                scale: elementScale
            )
            .padding(.top, 23 * elementScale)

            DesktopPlaybackControls(
                prominent: true,
                tint: .white,
                prominentWidth: layout.playerWidth,
                prominentScale: elementScale
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 22 * elementScale)

            Spacer()
        }
    }

    private func metadata(elementScale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5 * elementScale) {
            Text(model.player.currentSong?.name ?? L10n.string("ui.desktop.player.not_playing"))
                .font(
                    .system(
                        size: 18 * elementScale,
                        weight: .bold
                    )
                )
                .lineLimit(1)
            Text(
                [
                    model.player.currentSong?.artistText,
                    model.player.currentSong?.album?.name,
                ]
                .compactMap { $0 }
                .joined(
                    separator: L10n.string(
                        "ui.common.title_detail_separator"
                    )
                )
            )
            .font(
                .system(
                    size: 14 * elementScale,
                    weight: .medium
                )
            )
            .foregroundStyle(.white.opacity(0.60))
            .lineLimit(1)
        }
    }

    private func favoriteButton(elementScale: CGFloat) -> some View {
        Button {
            guard let song = model.player.currentSong else { return }
            model.library.toggle(song: song)
        } label: {
            Image(
                systemName: model.player.currentSong.map {
                    model.library.contains(song: $0)
                } == true ? "star.fill" : "star"
            )
            .font(
                .system(
                    size: 13 * elementScale,
                    weight: .semibold
                )
            )
            .frame(
                width: 28 * elementScale,
                height: 28 * elementScale
            )
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .modifier(DesktopNowPlayingCircularGlass())
    }

    private func playerMenu(elementScale: CGFloat) -> some View {
        Menu {
            if let song = model.player.currentSong {
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
                if model.settings.isContentFeatureEnabled(.downloads) {
                    Button("ui.common.download", systemImage: "arrow.down.circle") {
                        model.downloads.start(
                            song,
                            quality: model.settings.quality
                        )
                    }
                }
                DesktopPlaybackQualityMenu(model: model)
                Button("ui.floating_lyrics.title", systemImage: "text.quote") {
                    DesktopFloatingLyricsPanelController.shared.show(model: model) {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "main")
                    }
                }
                Button("ui.listen_together.title", systemImage: "person.2.wave.2") {
                    model.ui.sheet = .listenTogether
                }
                if model.settings.beatNetDebugEnabled {
                    Divider()
                    Button(
                        "ui.beatnet.debug.title",
                        systemImage: "waveform.path.ecg"
                    ) {
                        model.ui.sheet = .beatNetDebug
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(
                    .system(
                        size: 13 * elementScale,
                        weight: .semibold
                    )
                )
                .frame(
                    width: 28 * elementScale,
                    height: 28 * elementScale
                )
                .contentShape(.circle)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .tint(.white)
        .foregroundStyle(.white)
        .modifier(DesktopNowPlayingCircularGlass())
    }
}
