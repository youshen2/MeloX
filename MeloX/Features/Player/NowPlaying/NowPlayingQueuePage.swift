import SwiftUI

struct NowPlayingQueuePage: View {
    @Environment(PlayerStore.self) private var player

    let song: Song
    let presentation: NowPlayingLyricsPresentation
    let artworkNamespace: Namespace.ID
    let usesArtworkTransition: Bool
    let showsSongHeader: Bool
    let onSongHeaderHiddenChange: (Bool) -> Void
    let onSongHeaderOffsetChange: (CGFloat) -> Void

    @State private var songHeaderHeight = NowPlayingSongHeader.referenceHeight
    @State private var scrollOffset: CGFloat = 0
    @State private var isSongHeaderHidden = false
    @State private var isSongHeaderAtRest = true

    init(
        song: Song,
        presentation: NowPlayingLyricsPresentation,
        artworkNamespace: Namespace.ID,
        usesArtworkTransition: Bool = true,
        showsSongHeader: Bool = true,
        onSongHeaderHiddenChange:
            @escaping (Bool) -> Void = { _ in },
        onSongHeaderOffsetChange:
            @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.song = song
        self.presentation = presentation
        self.artworkNamespace = artworkNamespace
        self.usesArtworkTransition = usesArtworkTransition
        self.showsSongHeader = showsSongHeader
        self.onSongHeaderHiddenChange = onSongHeaderHiddenChange
        self.onSongHeaderOffsetChange = onSongHeaderOffsetChange
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                // Reserve the header space once. Pinning the overlay must not
                // resize the List or change its content at the scroll threshold.
                Color.clear
                    .frame(height: reservedSongHeaderHeight + 60)
                    .listRowInsets(.init())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)

                Section {
                    Text("ui.player.continue_playing")
                        .font(.title2.bold())
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .listRowInsets(.init())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if upcomingEntries.isEmpty {
                        ContentUnavailableView(
                            "ui.player.no_up_next",
                            systemImage: "list.bullet"
                        )
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(
                            .init(
                                top: 24,
                                leading: 0,
                                bottom: 24,
                                trailing: 0
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(upcomingEntries) { entry in
                            NowPlayingQueueRow(entry: entry)
                        }
                        .onMove(perform: moveQueueItems)
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.visible)
            .contentMargins(.top, 0, for: .scrollContent)
            // The mask also clips the system indicator. Start its track at
            // the visible queue edge without changing the content offset.
            .contentMargins(.top, visibleQueueTopInset, for: .scrollIndicators)
            .environment(\.defaultMinListRowHeight, 1)
            .environment(\.defaultMinListHeaderHeight, 0)
            .environment(\.editMode, .constant(.active))
            .mask {
                Rectangle()
                    .padding(.top, visibleQueueTopInset)
            }
            .overlay(alignment: .top) {
                // A single set of controls moves continuously, then stays at
                // the top without swapping between two header containers.
                NowPlayingQueueModeControls()
                    .padding(.vertical, 8)
                    .frame(height: 60)
                    .offset(y: modeControlsOffset)
            }
            .overlay(alignment: .top) {
                if presentation == .portrait && showsSongHeader {
                    NowPlayingSongHeader(
                        song: song,
                        artworkNamespace: artworkNamespace,
                        usesReferenceLayout: true,
                        usesArtworkTransition: usesArtworkTransition && isSongHeaderAtRest
                    )
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { newHeight in
                        if newHeight > 0 {
                            songHeaderHeight = newHeight
                        }
                    }
                    .offset(y: -scrollOffset)
                    .clipped()
                }
            }
            .padding(.bottom, bottomContentInset)
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    min(
                        max(geometry.contentOffset.y + geometry.contentInsets.top, 0),
                        reservedSongHeaderHeight
                    )
                }
            ) { _, offset in
                updateSongHeaderState(for: offset)
            }
        }
        .onAppear {
            if presentation == .portrait {
                scrollOffset = 0
                isSongHeaderHidden = false
                isSongHeaderAtRest = true
                onSongHeaderHiddenChange(false)
                onSongHeaderOffsetChange(0)
            }
        }
    }

    private var upcomingEntries: [UpcomingQueueEntry] {
        var occurrences: [Int: Int] = [:]
        return player.unplayedQueueIndices.compactMap { index in
            guard player.queue.indices.contains(index) else {
                return nil
            }
            let song = player.queue[index]
            let occurrence = occurrences[song.id, default: 0]
            occurrences[song.id] = occurrence + 1
            return UpcomingQueueEntry(
                id: UpcomingQueueEntry.ID(
                    songID: song.id,
                    occurrence: occurrence
                ),
                queueIndex: index,
                song: song
            )
        }
    }

    private var bottomContentInset: CGFloat {
        presentation == .portrait
            ? NowPlayingBottomControls.coreHeight
            : 12
    }

    private var reservedSongHeaderHeight: CGFloat {
        presentation == .portrait ? songHeaderHeight : 0
    }

    private var modeControlsOffset: CGFloat {
        max(reservedSongHeaderHeight - scrollOffset, 0)
    }

    private var visibleQueueTopInset: CGFloat {
        modeControlsOffset + 60
    }

    private func updateSongHeaderState(for offset: CGFloat) {
        guard presentation == .portrait else { return }

        scrollOffset = offset

        onSongHeaderOffsetChange(
            -min(offset, max(songHeaderHeight, 0))
        )

        let isHidden =
            songHeaderHeight > 0
            && offset >= songHeaderHeight
        if isSongHeaderHidden != isHidden {
            isSongHeaderHidden = isHidden
            onSongHeaderHiddenChange(isHidden)
        }

        let isAtRest = offset <= 0.5
        if isSongHeaderAtRest != isAtRest {
            isSongHeaderAtRest = isAtRest
        }
    }

    private func moveQueueItems(
        from source: IndexSet,
        to destination: Int
    ) {
        withAnimation(.smooth(duration: 0.28)) {
            player.moveUpcomingQueueItems(
                fromOffsets: source,
                toOffset: destination
            )
        }
    }
}

private struct NowPlayingQueueModeControls: View {
    @Environment(PlayerStore.self) private var player

    var body: some View {
        HStack(spacing: 14) {
            modeButton(
                systemImage: "shuffle",
                isSelected: player.isShuffled,
                accessibilityLabel:
                    player.isShuffled
                        ? L10n.string("ui.player.shuffle_off")
                        : L10n.string("ui.player.shuffle_on"),
                action: toggleShuffle
            )

            modeButton(
                systemImage: player.repeatMode.systemImage,
                isSelected: player.repeatMode != .off,
                accessibilityLabel:
                    player.repeatMode.accessibilityTitle,
                action: cycleRepeatMode
            )

            modeButton(
                systemImage: "infinity",
                isSelected: player.isAutoplayEnabled,
                accessibilityLabel:
                    player.isAutoplayEnabled
                        ? L10n.string("ui.player.autoplay_off")
                        : L10n.string("ui.player.autoplay_on"),
                action: toggleAutoplay
            )

            modeButton(
                systemImage: "circle.circle.fill",
                isSelected: player.isAutoMixEnabled,
                accessibilityLabel:
                    player.isAutoMixEnabled
                        ? L10n.string("ui.player.automix_off")
                        : L10n.string("ui.player.automix_on"),
                action: toggleAutoMix
            )
        }
        .disabled(player.isListenTogetherSessionActive)
        .accessibilityHint(
            player.isListenTogetherSessionActive
                ? L10n.string("ui.listen_together.playback_mode_managed")
                : ""
        )
    }

    private func modeButton(
        systemImage: String,
        isSelected: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .contentTransition(
                    .symbolEffect(.replace.downUp.wholeSymbol)
                )
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(
                    isSelected
                        ? .black.opacity(0.62)
                        : .white.opacity(0.86)
                )
                .background(
                    .white.opacity(isSelected ? 0.7 : 0.12),
                    in: .rect(cornerRadius: 22)
                )
                .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggleShuffle() {
        withAnimation(.smooth(duration: 0.34)) {
            player.toggleShuffle()
        }
    }

    private func cycleRepeatMode() {
        withAnimation(.smooth(duration: 0.34)) {
            player.cycleRepeatMode()
        }
    }

    private func toggleAutoplay() {
        withAnimation(.smooth(duration: 0.34)) {
            player.toggleAutoplay()
        }
    }

    private func toggleAutoMix() {
        withAnimation(.smooth(duration: 0.34)) {
            player.toggleAutoMix()
        }
    }
}

private struct NowPlayingQueueRow: View {
    @Environment(PlayerStore.self) private var player

    let entry: UpcomingQueueEntry

    var body: some View {
        Button(action: play) {
            HStack(spacing: 12) {
                ArtworkImage(
                    url: entry.song.album?.artworkURL,
                    cornerRadius: 6
                )
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.song.name)
                        .font(.body)
                        .lineLimit(1)

                    Text(entry.song.artistText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(
            .init(
                top: 4,
                leading: 0,
                bottom: 4,
                trailing: 0
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func play() {
        Task {
            await player.playFromQueue(at: entry.queueIndex)
        }
    }
}

private struct UpcomingQueueEntry: Identifiable {
    struct ID: Hashable {
        let songID: Int
        let occurrence: Int
    }

    let id: ID
    let queueIndex: Int
    let song: Song
}
