import SwiftUI
import UIKit

private struct MusicCollectionDetailMetricsKey: EnvironmentKey {
    static let defaultValue = MusicCollectionDetailMetrics()
}

extension EnvironmentValues {
    var musicCollectionDetailMetrics: MusicCollectionDetailMetrics {
        get { self[MusicCollectionDetailMetricsKey.self] }
        set { self[MusicCollectionDetailMetricsKey.self] = newValue }
    }
}

/// Apple Music places artwork beside metadata, followed by a full-width table.
struct MusicCollectionDetailLayoutView<Header: View, Tracks: View>: View {
    let palette: ArtworkDetailPalette
    let blurredBackdropImage: CGImage?
    var extendsPhoneHeaderUnderToolbar = false
    let onRefresh: () async -> Void
    @ViewBuilder let header: () -> Header
    @ViewBuilder let tracks: () -> Tracks

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let metrics = MusicCollectionDetailMetrics(
                viewport: proxy.size,
                isTablet: UIDevice.current.userInterfaceIdiom == .pad,
                usesAccessibilityText: dynamicTypeSize.isAccessibilitySize
            )

            ZStack {
                backdrop(metrics: metrics)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        header()
                            .padding(.horizontal, metrics.usesAdaptiveHeader ? MusicCollectionDetailMetrics.horizontalPadding : 0)
                        tracks()
                            .padding(.horizontal, metrics.usesAdaptiveHeader ? 12 : 0)
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .refreshable { await onRefresh() }
                .ignoresSafeArea(
                    .container,
                    edges: extendsPhoneHeaderUnderToolbar && !metrics.usesAdaptiveHeader ? .top : []
                )
            }
            .environment(\.musicCollectionDetailMetrics, metrics)
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func backdrop(metrics: MusicCollectionDetailMetrics) -> some View {
        MusicCollectionArtworkBackdrop(blurredArtworkImage: blurredBackdropImage, palette: palette)
    }
}

struct AdaptiveMusicCollectionHero: View {
    let artworkURL: URL?
    let title: String
    let subtitle: String
    let metadataText: String?
    var descriptionText: String? = nil
    let tracks: [Song]
    let sourceID: Int
    let isSaved: Bool
    var isPreparingPlayback = false
    let onToggleSaved: () -> Void
    var onPlayAll: ((Bool) async -> Void)? = nil

    @Environment(\.musicCollectionDetailMetrics) private var metrics

    var body: some View {
        Group {
            if metrics.usesInlineHeader {
                HStack(alignment: .top, spacing: MusicCollectionDetailMetrics.columnSpacing) {
                    artwork
                    information
                        .frame(minHeight: metrics.artworkSize, alignment: .top)
                }
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    artwork
                    information
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }

    private var artwork: some View {
        ArtworkImage(url: artworkURL, cornerRadius: 14)
            .frame(width: metrics.artworkSize, height: metrics.artworkSize)
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(false)
            .accessibilityLabel(L10n.format("ui.song.artwork_accessibility", title))
            .accessibilityIdentifier("collection-detail-artwork")
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.weight(.bold))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let metadataText, !metadataText.isEmpty {
                Text(metadataText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if metrics.usesWideHeader {
                Spacer(minLength: 16)
            }
            if let descriptionText {
                ExpandablePlaylistDescription(description: descriptionText, horizontalPadding: 0)
                    .padding(.top, 12)
            }
            MusicCollectionPrimaryActions(
                tracks: tracks,
                sourceID: sourceID,
                isSaved: isSaved,
                isPreparingPlayback: isPreparingPlayback,
                onToggleSaved: onToggleSaved,
                onPlayAll: onPlayAll
            )
            .padding(.top, 8)
        }
        .padding(.top, metrics.usesWideHeader ? 24 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
