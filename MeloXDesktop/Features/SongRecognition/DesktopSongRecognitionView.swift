import AppKit
import SwiftUI

struct DesktopSongRecognitionView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recognition = SongRecognitionStore()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ui.recognition.title")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                if showsRestartButton {
                    Button("ui.recognition.restart", systemImage: "arrow.clockwise") {
                        startRecognition()
                    }
                }
                Button("ui.common.done") { dismiss() }
            }
            .padding(24)

            Divider()

            Group {
                switch recognition.phase {
                case .ready:
                    readyView
                case .requestingPermission:
                    progressView(
                        recognition.audioSource.preparationTitle,
                        detail: recognition.audioSource.permissionMessage
                    )
                case .listening:
                    listeningView
                case .matching:
                    progressView(
                        L10n.string("ui.recognition.matching"),
                        detail: L10n.string("ui.recognition.matching_message")
                    )
                case .results:
                    resultList
                case .noMatch:
                    noMatchView
                case .failed(let failure):
                    failureView(failure)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 660)
        .onDisappear { recognition.cancel() }
    }

    private var readyView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 88, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
            VStack(spacing: 8) {
                Text(
                    model.settings.songRecognition.audioSource == .microphone
                        ? L10n.string("ui.desktop.recognition.ready.title")
                        : L10n.string("ui.desktop.recognition.ready.system_audio")
                )
                    .font(.title.bold())
                Text(readyDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 470)
            }
            VStack(spacing: 8) {
                Picker("ui.desktop.recognition.source", selection: settingsAudioSource) {
                    ForEach(SongRecognitionAudioSource.allCases) { source in
                        Label(source.title, systemImage: source.systemImage).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 340)
                Text(model.settings.songRecognition.audioSource.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 470)
            }
            Picker("ui.settings.content.recognition_duration", selection: settingsDuration) {
                ForEach(SongRecognitionDuration.allCases) { duration in
                    Text(
                        L10n.joined(
                            [duration.title, duration.detail],
                            separatorKey: "ui.common.metadata_separator"
                        )
                    )
                    .tag(duration)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 540)

            Button("ui.recognition.start", systemImage: model.settings.songRecognition.audioSource.systemImage) {
                startRecognition()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding(36)
    }

    private var listeningView: some View {
        VStack(spacing: 22) {
            if recognition.isContinuous, !recognition.results.isEmpty {
                resultList
            } else {
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 76, weight: .medium))
                    .foregroundStyle(.red)
                    .symbolEffect(
                        .variableColor.iterative,
                        options: .repeating.speed(1.2),
                        isActive: !reduceMotion
                    )
                Text(
                    recognition.isContinuous
                        ? L10n.string("ui.recognition.continuous")
                        : L10n.string("ui.recognition.listening")
                )
                    .font(.title.bold())
                Text(
                    recognition.audioSource == .microphone
                        ? L10n.string("ui.desktop.recognition.listening_message")
                        : L10n.string("ui.desktop.recognition.listening_system_audio")
                )
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button(
                recognition.isContinuous
                    ? L10n.string("ui.recognition.stop")
                    : L10n.string("ui.common.cancel"),
                role: .cancel
            ) {
                if recognition.isContinuous {
                    recognition.stopContinuousRecognition()
                } else {
                    recognition.cancel()
                }
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 24)
        }
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("ui.recognition.results")
                        .font(.title2.bold())
                    Spacer()
                    Text(L10n.format("ui.common.song_count", recognition.results.count))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)

                ForEach(Array(recognition.results.enumerated()), id: \.element.id) { index, result in
                    Button {
                        play(result)
                    } label: {
                        HStack(spacing: 12) {
                            DesktopArtworkView(url: result.song.album?.artworkURL, cornerRadius: 7)
                                .frame(width: 54, height: 54)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.song.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(
                                    L10n.joined(
                                        [
                                            result.song.artistText,
                                            result.song.album?.name ?? "",
                                        ],
                                        separatorKey:
                                            "ui.common.title_detail_separator"
                                    )
                                )
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                model.library.toggle(song: result.song)
                            } label: {
                                Image(systemName: model.library.contains(song: result.song) ? "heart.fill" : "heart")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(model.library.contains(song: result.song) ? .red : .secondary)
                            Image(systemName: "play.fill")
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if index < recognition.results.count - 1 { Divider() }
                }
            }
            .padding(24)
        }
    }

    private var noMatchView: some View {
        ContentUnavailableView {
            Label("ui.recognition.no_match", systemImage: "questionmark.circle")
        } description: {
            Text("ui.recognition.no_match_message")
        } actions: {
            Button("ui.recognition.try_again", systemImage: "arrow.clockwise") { startRecognition() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func failureView(_ failure: SongRecognitionFailure) -> some View {
        ContentUnavailableView {
            Label("ui.recognition.failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(failure.message)
        } actions: {
            if failure.opensSystemSettings {
                Button(recognition.audioSource.settingsTitle, systemImage: "gear") {
                    if let url = recognition.audioSource.settingsURL {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            Button("ui.common.retry", systemImage: "arrow.clockwise") { startRecognition() }
                .buttonStyle(.bordered)
        }
    }

    private func progressView(_ title: String, detail: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(title).font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("ui.common.cancel", role: .cancel) { recognition.cancel() }
        }
        .padding(36)
    }

    private var settingsDuration: Binding<SongRecognitionDuration> {
        Binding(
            get: { model.settings.songRecognition.duration },
            set: { model.settings.songRecognition.duration = $0 }
        )
    }

    private var settingsAudioSource: Binding<SongRecognitionAudioSource> {
        Binding(
            get: { model.settings.songRecognition.audioSource },
            set: { model.settings.songRecognition.audioSource = $0 }
        )
    }

    private var showsRestartButton: Bool {
        switch recognition.phase {
        case .results, .noMatch, .failed: true
        default: false
        }
    }

    private var readyDescription: String {
        let duration = model.settings.songRecognition.duration
        if duration.isContinuous {
            return L10n.string("ui.desktop.recognition.ready.continuous")
        }
        return L10n.format("ui.desktop.recognition.ready.limited", duration.title)
    }

    private func startRecognition() {
        let settings = model.settings.songRecognition
        if settings.audioSource == .microphone, model.player.isPlaying {
            model.player.togglePlayback()
        }
        recognition.start(api: model.api, duration: settings.duration, source: settings.audioSource)
    }

    private func play(_ result: SongRecognitionResult) {
        recognition.prepareForResultPlayback()
        Task {
            await model.player.play(
                result.song,
                in: recognition.results.map(\.song),
                startAt: result.playbackPosition
            )
        }
    }
}
