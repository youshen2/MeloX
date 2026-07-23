import SwiftUI

struct DownloadsView: View {
    @Environment(DownloadStore.self) private var downloads
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @State private var showsClearConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                Toggle(
                    "按播放次数自动缓存",
                    isOn: $settings.automaticallyCachesFrequentlyPlayedSongs
                )

                if settings.automaticallyCachesFrequentlyPlayedSongs {
                    Picker(
                        "触发次数",
                        selection: $settings.automaticCachePlaybackThreshold
                    ) {
                        ForEach(AppSettings.automaticCachePlaybackThresholdOptions, id: \.self) { count in
                            Text("\(count) 次").tag(count)
                        }
                    }

                    Picker("自动缓存音质", selection: $settings.automaticCacheQuality) {
                        ForEach(MusicQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }
                }
            } header: {
                Text("自动缓存")
            } footer: {
                Text("开启后，歌曲成功开始播放达到所选次数时会自动下载；已下载和正在下载的歌曲不会重复处理。")
            }

            if !activeDownloads.isEmpty {
                Section("正在下载") {
                    ForEach(activeDownloads) { download in
                        VStack(alignment: .leading, spacing: 8) {
                            TrackRowView(song: download.song, showsArtwork: true)

                            if let fractionCompleted = download.fractionCompleted {
                                ProgressView(value: fractionCompleted)
                                    .progressViewStyle(.linear)
                                    .accessibilityValue(
                                        fractionCompleted.formatted(.percent.precision(.fractionLength(0)))
                                    )
                            }

                            HStack {
                                Text(download.quality.title)
                                Spacer()
                                Text(progressText(for: download))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                downloads.cancel(songID: download.id)
                            } label: {
                                Label("取消", systemImage: "xmark")
                            }
                        }
                    }
                }
            }

            if !downloads.downloads.isEmpty {
                Section {
                    Button {
                        Task { await player.playAll(downloads.downloadedSongs) }
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                    }

                    ForEach(downloads.downloads) { download in
                        Button {
                            Task {
                                await player.play(
                                    download.song,
                                    in: downloads.downloadedSongs
                                )
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                TrackRowView(song: download.song, showsArtwork: true)
                                HStack {
                                    Text(download.quality.title)
                                    Spacer()
                                    Text(download.byteCount.formatted(.byteCount(style: .file)))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                downloads.remove(songID: download.id)
                            } label: {
                                Label("删除下载", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("已下载")
                } footer: {
                    Text(storageSummary)
                }
            }

            if downloads.downloads.isEmpty && activeDownloads.isEmpty {
                Section {
                    ContentUnavailableView(
                        "还没有下载歌曲",
                        systemImage: "arrow.down.circle",
                        description: Text("在歌曲的更多操作菜单中选择“下载歌曲”。")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("已下载")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("全部删除", role: .destructive) {
                    showsClearConfirmation = true
                }
                .disabled(downloads.downloads.isEmpty && activeDownloads.isEmpty)
            }
        }
        .confirmationDialog(
            "删除全部已下载歌曲？",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("全部删除", role: .destructive) {
                downloads.removeAll()
            }
        } message: {
            Text("歌曲文件将从本机移除，此操作无法撤销。")
        }
    }

    private var activeDownloads: [ActiveSongDownload] {
        downloads.activeDownloads.values.sorted {
            $0.song.name.localizedCompare($1.song.name) == .orderedAscending
        }
    }

    private func progressText(for download: ActiveSongDownload) -> String {
        let received = download.receivedByteCount.formatted(.byteCount(style: .file))
        guard let expected = download.expectedByteCount else {
            return received
        }
        let total = expected.formatted(.byteCount(style: .file))
        let percentage = download.fractionCompleted?.formatted(
            .percent.precision(.fractionLength(0))
        ) ?? ""
        return "\(received) / \(total)  \(percentage)"
    }

    private var storageSummary: String {
        "共 \(downloads.downloads.count) 首，占用 \(downloads.totalByteCount.formatted(.byteCount(style: .file)))"
    }
}
