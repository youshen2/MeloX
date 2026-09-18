import SwiftUI

struct DesktopRouteView: View {
    let route: DesktopRoute

    var body: some View {
        switch route {
        case .album(let id):
            DesktopAlbumDetailView(albumID: id)
        case .artist(let id):
            DesktopArtistDetailView(artistID: id)
        case .dailySongs:
            DesktopPersonalizedPlaylistView(kind: .dailySongs)
        case .privateRoaming:
            DesktopPersonalizedPlaylistView(kind: .privateRoaming)
        case .playlist(let id):
            DesktopPlaylistDetailView(playlistID: id)
        case .podcast(let id):
            DesktopPodcastDetailView(podcastID: id)
        case .podcastCategory(let id, let title):
            DesktopPodcastCategoryView(categoryID: id, title: title)
        case .section(let section):
            DesktopSectionContentView(section: section)
        case .similarSongs(let songID):
            DesktopPersonalizedPlaylistView(
                kind: .similarSongs(seedSongID: songID)
            )
        case .song(let id):
            DesktopSongDetailView(songID: id)
        }
    }
}

struct DesktopCollectionSupplementaryAction {
    let title: String
    let systemImage: String
    var isRunning = false
    var isDisabled = false
    let action: () -> Void
}

struct DesktopCollectionHeader: View {
    let artworkURL: URL?
    let kind: String
    let title: String
    let subtitle: String?
    let metadata: String?
    let description: String?
    let songs: [Song]
    let sourceID: Int?
    var isFavorite = false
    var favoriteAction: (() -> Void)?
    var shareURL: URL?
    var artworkSystemImage: String?
    var artworkTint: Color = .red
    var supplementaryAction: DesktopCollectionSupplementaryAction?
    var onPlayAll: ((Bool) async -> Void)?

    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDescriptionExpanded = false
    @State private var isArtworkHovered = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 34) {
            artwork(size: 278)
            details
                .padding(.bottom, 6)
            Spacer(minLength: 0)
        }
    }

    private func artwork(size: CGFloat) -> some View {
        artworkContent
            .frame(width: size, height: size)
            .scaleEffect(isArtworkHovered ? 1.012 : 1)
            .shadow(
                color: .black.opacity(isArtworkHovered ? 0.24 : 0.20),
                radius: isArtworkHovered ? 22 : 18,
                y: isArtworkHovered ? 12 : 10
            )
            .onHover { isArtworkHovered = $0 }
            .animation(
                reduceMotion
                    ? nil
                    : .snappy(duration: 0.25, extraBounce: 0.04),
                value: isArtworkHovered
            )
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let artworkSystemImage {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(artworkTint.opacity(0.14))
                Image(systemName: artworkSystemImage)
                    .font(.system(size: 92, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(artworkTint)
            }
            .clipShape(.rect(cornerRadius: 11, style: .continuous))
        } else {
            DesktopArtworkView(url: artworkURL, cornerRadius: 11)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .lineLimit(2)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            if let metadata, !metadata.isEmpty {
                Text(metadata)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            descriptionView
            actions
                .padding(.top, 10)
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    @ViewBuilder
    private var descriptionView: some View {
        if let description, !description.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(description)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(isDescriptionExpanded ? nil : 3)
                    .textSelection(.enabled)

                if description.count > 120 || description.contains("\n") {
                    Button(
                        isDescriptionExpanded
                            ? L10n.string("ui.common.collapse")
                            : L10n.string("ui.common.more")
                    ) {
                        withAnimation(
                            reduceMotion ? nil : .smooth(duration: 0.24)
                        ) {
                            isDescriptionExpanded.toggle()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("ui.common.play", systemImage: "play.fill") {
                Task {
                    if let onPlayAll {
                        await onPlayAll(false)
                    } else {
                        await model.player.playAll(songs, sourceID: sourceID)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(songs.isEmpty)

            Button("ui.player.shuffle", systemImage: "shuffle") {
                Task {
                    if let onPlayAll {
                        await onPlayAll(true)
                    } else {
                        await model.player.playAll(
                            songs.shuffled(),
                            sourceID: sourceID
                        )
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(songs.isEmpty)

            if let supplementaryAction {
                Button(action: supplementaryAction.action) {
                    Label {
                        Text(supplementaryAction.title)
                    } icon: {
                        if supplementaryAction.isRunning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: supplementaryAction.systemImage)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(
                    supplementaryAction.isDisabled
                        || supplementaryAction.isRunning
                )
            }

            if let favoriteAction {
                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.bordered)
                .help(
                    isFavorite
                        ? L10n.string("ui.desktop.collection.unfavorite")
                        : L10n.string("ui.desktop.collection.favorite")
                )
            }

            if model.settings.isContentFeatureEnabled(.downloads)
                || shareURL != nil {
                Menu {
                    if model.settings.isContentFeatureEnabled(.downloads) {
                        Button("ui.desktop.collection.download_all", systemImage: "arrow.down.circle") {
                            model.downloads.start(
                                songs,
                                quality: model.settings.quality
                            )
                        }
                        .disabled(songs.isEmpty)
                    }

                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label("ui.common.share", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(L10n.string("ui.common.more"))
            }
        }
    }
}

struct DesktopCollectionTrackList: View {
    let songs: [Song]
    let sourceID: Int?
    var showsAlbumColumn = true
    var usesTrackNumbers = false
    var groupsByDisc = false
    var footer: (() -> AnyView)? = nil

    var body: some View {
        let entries = makeEntries()
        let discGroups = groupsByDisc
            ? makeDiscGroups(from: entries)
            : []

        LazyVStack(spacing: 1) {
            if groupsByDisc, discGroups.count > 1 {
                ForEach(discGroups) { group in
                    Text(L10n.format("ui.desktop.collection.disc", group.id))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(
                            .top,
                            group.id == discGroups.first?.id ? 0 : 18
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 5)

                    ForEach(group.entries) { entry in
                        row(entry)
                    }
                }
            } else {
                ForEach(entries) { entry in
                    row(entry)
                }
            }

            if let footer {
                footer()
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: TrackEntry) -> some View {
        DesktopTrackRow(
            song: entry.song,
            index: entry.index,
            songs: songs,
            sourceID: sourceID,
            showsAlbumColumn: showsAlbumColumn,
            displayNumber: usesTrackNumbers
                ? String(entry.song.trackNumber ?? entry.index + 1)
                : nil
        )
    }

    private func makeEntries() -> [TrackEntry] {
        Array(songs.enumerated()).map {
            TrackEntry(index: $0.offset, song: $0.element)
        }
    }

    private func makeDiscGroups(
        from entries: [TrackEntry]
    ) -> [DiscGroup] {
        var order: [String] = []
        var values: [String: [TrackEntry]] = [:]

        for entry in entries {
            let key = normalizedDisc(entry.song.disc)
            if values[key] == nil {
                order.append(key)
                values[key] = []
            }
            values[key, default: []].append(entry)
        }

        return order.map {
            DiscGroup(id: $0, entries: values[$0] ?? [])
        }
    }

    private func normalizedDisc(_ value: String?) -> String {
        guard let value else { return "1" }
        let digits = value.filter(\.isNumber)
        if let number = Int(digits) {
            return String(number)
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "1" : normalized
    }

    private struct TrackEntry: Identifiable {
        let index: Int
        let song: Song

        var id: Int { song.id }
    }

    private struct DiscGroup: Identifiable, Equatable {
        let id: String
        let entries: [TrackEntry]

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
}

struct DesktopDetailLoadingView: View {
    let message: String

    var body: some View {
        Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .desktopLoadingStatus(message, isPresented: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }
}

struct DesktopDetailErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("ui.error.music_content_load_failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("ui.common.retry", action: retry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
