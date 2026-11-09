import SwiftUI

struct PodcastCardView: View {
    let podcast: Podcast
    var artworkSize: CGFloat = 164

    var body: some View {
        MediaCardView(
            title: podcast.name,
            subtitle: podcast.subtitle,
            artworkURL: podcast.artworkURL,
            artworkSize: artworkSize
        )
        .frame(width: artworkSize)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        [podcast.name, podcast.subtitle]
            .compactMap { $0?.podcastNonempty }
            .joined(separator: L10n.string("ui.common.spoken_separator"))
    }
}

struct PodcastListRow: View {
    let podcast: Podcast

    var body: some View {
        HStack(spacing: 13) {
            ArtworkImage(
                url: podcast.artworkURL,
                cornerRadius: 10
            )
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 5) {
                Text(podcast.name)
                    .font(.headline)
                    .lineLimit(2)

                if let subtitle = podcast.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if podcast.programCount > 0 {
                        Text(L10n.format("ui.podcasts.episode_count_short", podcast.programCount))
                    }
                    if podcast.subscriberCount > 0 {
                        Label(
                            podcast.subscriberCount.podcastCountText,
                            systemImage: "person.2"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.format("ui.podcasts.accessibility_episode_count", podcast.name, podcast.programCount)
        )
    }
}

struct PodcastProgramRowLabel: View {
    let program: PodcastProgram

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ArtworkImage(
                url: program.artworkURL,
                cornerRadius: 9
            )
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(program.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: 7) {
                    if let dateText = program.createTime?.podcastDateText {
                        Text(dateText)
                    }
                    if program.durationMS > 0 {
                        Text(program.durationMS.podcastDurationText)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if program.listenerCount > 0 {
                    Label(
                        L10n.format("ui.podcasts.play_count", program.listenerCount.podcastCountText),
                        systemImage: "headphones"
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.format(
                "ui.accessibility.podcast_title_and_duration",
                program.name,
                program.durationMS.podcastDurationText
            )
        )
    }
}

struct PodcastProgramListRow: View {
    let program: PodcastProgram
    let isCurrent: Bool
    let isPlaying: Bool
    let play: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(
                value: MusicRoute.podcastProgram(program)
            ) {
                PodcastProgramRowLabel(program: program)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: play) {
                Image(
                    systemName:
                        isCurrent && isPlaying
                        ? "pause.circle.fill"
                        : "play.circle.fill"
                )
                .font(.title2)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(program.playbackSong == nil)
            .accessibilityLabel(
                isCurrent && isPlaying
                    ? L10n.string("ui.podcasts.pause_episode")
                    : L10n.string("ui.podcasts.play_episode")
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PodcastCategoryTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let category: PodcastCategory

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(
                url: category.artworkURL,
                cornerRadius: 10
            )
            .frame(width: 48, height: 48)

            Text(category.localizedName)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct FeaturedPodcastView: View {
    let podcast: Podcast

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkImage(
                url: podcast.artworkURL,
                cornerRadius: 22,
                aspectRatio: 1.55
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(.rect(cornerRadius: 22))

            VStack(alignment: .leading, spacing: 6) {
                Text("ui.podcasts.editors_choice")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))

                Text(podcast.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let subtitle = podcast.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }
            }
            .padding(20)
            .padding(.trailing, 20)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

extension Int {
    var podcastCountText: String {
        formatted(
            .number
                .notation(.compactName)
                .locale(L10n.locale)
        )
    }

    var podcastDurationText: String {
        let totalSeconds = Swift.max(self, 0) / 1_000
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func podcastDecimal(_ value: Double) -> String {
        if value >= 10 || value.rounded() == value {
            return String(Int(value.rounded()))
        }
        return value.formatted(
            .number
                .precision(.fractionLength(1))
                .locale(L10n.locale)
        )
    }
}

extension Int64 {
    var podcastDateText: String {
        Date(
            timeIntervalSince1970: Double(self) / 1_000
        )
        .formatted(
            .dateTime
                .year()
                .month(.abbreviated)
                .day()
                .locale(L10n.locale)
        )
    }
}
