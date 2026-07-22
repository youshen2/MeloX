import SwiftUI

struct NowPlayingProgressControl: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let song: Song

    var body: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { min(player.progress, progressMaximum) },
                    set: { player.seek(to: $0) }
                ),
                in: 0...progressMaximum
            )
            .sliderThumbVisibility(.hidden)
            .tint(.white)
            .accessibilityLabel("播放进度")
            .accessibilityValue("已播放 \(formatTime(player.progress))，总时长 \(formatTime(progressMaximum))")

            HStack {
                Text(formatTime(player.progress))

                Spacer()

                Text("−\(formatTime(max(player.duration - player.progress, 0)))")
            }
            .overlay {
                qualityMenu
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
        }
        .frame(height: 52)
    }

    private var progressMaximum: TimeInterval {
        max(player.duration, TimeInterval(song.durationMS) / 1_000, 1)
    }

    private var qualityMenu: some View {
        Menu {
            Picker("音质", selection: qualityBinding) {
                ForEach(MusicQuality.allCases) { quality in
                    Text(quality.title).tag(quality)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(settings.quality.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7, weight: .semibold))
            }
            .contentShape(.rect)
        }
        .accessibilityLabel("播放音质")
        .accessibilityValue(settings.quality.title)
        .accessibilityHint("轻点调整当前歌曲音质")
    }

    private var qualityBinding: Binding<MusicQuality> {
        Binding(
            get: { settings.quality },
            set: { quality in
                guard settings.quality != quality else { return }
                settings.quality = quality
                Task {
                    await player.reloadCurrentSongForQualityChange()
                }
            }
        )
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let seconds = max(0, Int(value))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct NowPlayingTransportControls: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player

    var body: some View {
        HStack {
            Spacer()

            Button {
                Task { await player.previous() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 34, weight: .medium))
                    .frame(width: 64, height: 64)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("上一首")

            Spacer()

            Button {
                player.togglePlayback()
            } label: {
                Group {
                    if player.isLoading {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 48, weight: .medium))
                            .contentTransition(
                                accessibilityReduceMotion
                                    ? .identity
                                    : .symbolEffect(
                                        .replace.downUp.wholeSymbol,
                                        options: .speed(1.25)
                                    )
                            )
                            .animation(
                                accessibilityReduceMotion
                                    ? nil
                                    : .snappy(duration: 0.28, extraBounce: 0),
                                value: player.isPlaying
                            )
                    }
                }
                .frame(width: 64, height: 64)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

            Spacer()

            Button {
                Task { await player.next() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 34, weight: .medium))
                    .frame(width: 64, height: 64)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下一首")

            Spacer()
        }
        .frame(height: 82)
    }
}

struct NowPlayingVolumeControl: View {
    @Environment(PlayerStore.self) private var player

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.caption2)

            Slider(
                value: Binding(
                    get: { player.volume },
                    set: { player.setVolume($0) }
                ),
                in: 0...1
            )
            .tint(.white)
            .accessibilityLabel("音量")

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.62))
        .frame(height: 42)
    }
}

struct NowPlayingPageSelector: View {
    @Environment(AppSettings.self) private var settings

    @Binding var page: NowPlayingPage

    var body: some View {
        HStack {
            Spacer()

            pageButton(
                page: .lyrics,
                systemImage: "quote.bubble",
                accessibilityLabel: "歌词"
            )

            Spacer()

            Menu {
                Picker("歌词样式", selection: lyricsStyleBinding) {
                    ForEach([LyricsStyle.appleMusic, .eva]) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }

                TextPVStyleMenu(page: $page)
            } label: {
                Image(systemName: "textformat.size")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("歌词样式")
            .accessibilityValue(settings.lyricsStyle.title)
            .accessibilityHint("轻点切换歌词样式")

            Spacer()

            pageButton(
                page: .queue,
                systemImage: "list.bullet",
                accessibilityLabel: "播放队列"
            )

            Spacer()
        }
        .foregroundStyle(.white.opacity(0.72))
        .frame(height: 50)
    }

    private var lyricsStyleBinding: Binding<LyricsStyle> {
        Binding(
            get: { settings.lyricsStyle },
            set: { style in
                settings.lyricsStyle = style
                withAnimation(.smooth(duration: 0.3)) {
                    page = .lyrics
                }
            }
        )
    }

    private func pageButton(
        page destination: NowPlayingPage,
        systemImage: String,
        accessibilityLabel: String
    ) -> some View {
        let isSelected = page == destination

        return Button {
            withAnimation(.smooth(duration: 0.4)) {
                page = isSelected ? .artwork : destination
            }
        } label: {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.white.opacity(isSelected ? 0.2 : 0), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
