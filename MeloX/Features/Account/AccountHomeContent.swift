import SwiftUI

struct AccountHomeContent: View {
    let profile: AccountProfile
    let detail: AccountDetail?
    let playlists: [Playlist]
    let palette: ArtworkDetailPalette
    let blurredBackdropImage: CGImage?
    let isLoading: Bool
    let failureMessage: String?
    let onRetry: () -> Void
    let onRefresh: () async -> Void

    var body: some View {
        ZStack {
            MusicCollectionArtworkBackdrop(
                blurredArtworkImage: blurredBackdropImage,
                palette: palette
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    AccountProfileDetailHero(
                        profile: profile,
                        detail: detail,
                        playlistCount: playlists.count
                    )

                    AccountPlaylistContent(
                        playlists: playlists,
                        isLoading: isLoading,
                        failureMessage: failureMessage,
                        onRetry: onRetry
                    )
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await onRefresh()
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct AccountProfileDetailHero: View {
    let profile: AccountProfile
    let detail: AccountDetail?
    let playlistCount: Int

    var body: some View {
        VStack(spacing: 0) {
            ArtworkImage(url: profile.artworkURL, cornerRadius: 1_000)
                .containerRelativeFrame(.horizontal) { width, _ in
                    min(width * 0.52, 220)
                }
                .clipShape(.circle)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

            Text(profile.nickname)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .accessibilityAddTraits(.isHeader)

            if let signature = profile.signature?.nonemptyAccountText {
                Text(signature)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.top, 8)
                    .padding(.horizontal, 28)
            }

            if let detail {
                Text("Lv.\(detail.level) · 累计听歌 \(detail.listenSongs.formatted()) 首")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 7)
            }

            Text("用户 ID \(profile.id.formatted())")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 5)

            AccountProfileMetrics(
                follows: profile.follows,
                followers: profile.followeds,
                playlistCount: profile.playlistCount ?? playlistCount
            )
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 26)
    }
}

private struct AccountProfileMetrics: View {
    let follows: Int?
    let followers: Int?
    let playlistCount: Int

    var body: some View {
        HStack(spacing: 0) {
            metric(value: follows, title: "关注")
            Divider()
                .frame(height: 30)
            metric(value: followers, title: "粉丝")
            Divider()
                .frame(height: 30)
            metric(value: playlistCount, title: "歌单")
        }
        .frame(maxWidth: 340)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }

    private func metric(value: Int?, title: String) -> some View {
        VStack(spacing: 3) {
            Text(value?.formatted() ?? "—")
                .font(.headline)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AccountPlaylistContent: View {
    let playlists: [Playlist]
    let isLoading: Bool
    let failureMessage: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("歌单")
                    .font(.title3.weight(.bold))
                Text(playlists.count.formatted())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if playlists.isEmpty {
                emptyContent
            } else {
                playlistRows

                if let failureMessage {
                    AccountRefreshFailureRow(
                        message: failureMessage,
                        onRetry: onRetry
                    )
                    .padding(.top, 12)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if isLoading {
            ProgressView("正在读取歌单")
                .tint(.primary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if let failureMessage {
            ConnectionUnavailableView(
                message: failureMessage,
                retry: onRetry
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ContentUnavailableView("暂无歌单", systemImage: "music.note.list")
                .frame(maxWidth: .infinity, minHeight: 180)
        }
    }

    private var playlistRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(playlists) { playlist in
                NavigationLink(value: MusicRoute.playlist(playlist)) {
                    AccountPlaylistRow(playlist: playlist)
                }
                .buttonStyle(.plain)
                .musicMatchedTransitionSource(for: .playlist(playlist))

                if playlist.id != playlists.last?.id {
                    Divider()
                        .overlay(Color.primary.opacity(0.12))
                        .padding(.leading, 92)
                        .padding(.trailing, 20)
                }
            }
        }
    }
}

private struct AccountPlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: playlist.artworkURL, cornerRadius: 8)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(2)

                Text("\(playlist.trackCount.formatted()) 首歌曲")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}

private struct AccountRefreshFailureRow: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Label("部分主页内容未能更新", systemImage: "wifi.exclamationmark")
                .font(.subheadline.weight(.medium))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Button("重新载入", action: onRetry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

private extension String {
    var nonemptyAccountText: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
