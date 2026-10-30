import SwiftUI
import UIKit

struct SongRecognitionView: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings

    @State private var recognition = SongRecognitionStore()

    var body: some View {
        Group {
            switch recognition.phase {
            case .ready:
                readyView
            case .requestingPermission:
                progressView(
                    title: recognition.audioSource.preparationTitle,
                    description: recognition.audioSource.permissionMessage
                )
            case .listening:
                if recognition.isContinuous {
                    continuousListeningView
                } else {
                    listeningView
                }
            case .matching:
                progressView(
                    title: L10n.string("ui.recognition.matching"),
                    description: L10n.string("ui.recognition.matching_message")
                )
            case .results:
                resultsView
            case .noMatch:
                noMatchView
            case .failed(let failure):
                failureView(failure)
            }
        }
        .navigationTitle("ui.recognition.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsRestartButton {
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        "ui.recognition.restart",
                        systemImage: "arrow.clockwise",
                        action: startRecognition
                    )
                }
            }
        }
        .alert(
            "ui.error.favorite_failed",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.clearError() } }
            )
        ) {
            Button("ui.common.ok", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? L10n.string("ui.common.unknown_error"))
        }
        .onDisappear {
            recognition.cancel()
        }
    }

    private var readyView: some View {
        ContentUnavailableView {
            Label("ui.recognition.title", systemImage: "waveform")
        } description: {
            Text(readyDescription)
        } actions: {
            Picker("ui.recognition.source", selection: audioSourceBinding) {
                ForEach(SongRecognitionAudioSource.availableCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            Button(
                "ui.recognition.start",
                systemImage: settings.songRecognition.audioSource.systemImage,
                action: startRecognition
            )
            .buttonStyle(.borderedProminent)
        }
    }

    private var listeningView: some View {
        VStack(spacing: 22) {
            Spacer()

            listeningSymbol

            VStack(spacing: 8) {
                Text("ui.recognition.listening")
                    .font(.title2.bold())
                Text(
                    recognition.audioSource == .microphone ? L10n.format(
                        "ui.recognition.listening_message",
                        settings.songRecognition.duration.title
                    ) : recognition.audioSource.detail
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("ui.common.cancel", role: .cancel) {
                recognition.cancel()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }

    private var continuousListeningView: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    listeningSymbol

                    VStack(spacing: 6) {
                        Text("ui.recognition.continuous")
                            .font(.title3.bold())
                        Text("ui.recognition.continuous_message")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("ui.recognition.stop", role: .cancel) {
                        recognition.stopContinuousRecognition()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowSeparator(.hidden)
            }

            if !recognition.results.isEmpty {
                Section("ui.recognition.results") {
                    ForEach(recognition.results) { result in
                        recognitionResultRow(result)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var resultsView: some View {
        List {
            Section("ui.recognition.results") {
                ForEach(recognition.results) { result in
                    recognitionResultRow(result)
                }
            }
        }
        .listStyle(.plain)
    }

    private var listeningSymbol: some View {
        Image(systemName: "waveform")
            .font(.system(size: 64, weight: .medium))
            .foregroundStyle(.tint)
            .symbolEffect(
                .variableColor.iterative,
                options: .repeating.speed(1.2),
                isActive: !accessibilityReduceMotion
            )
            .accessibilityHidden(true)
    }

    private func recognitionResultRow(
        _ result: SongRecognitionResult
    ) -> some View {
        Button {
            play(result)
        } label: {
            TrackRowView(
                song: result.song,
                showsArtwork: true
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button {
                library.toggle(song: result.song)
            } label: {
                Label(
                    library.contains(song: result.song)
                        ? L10n.string("ui.common.unfavorite")
                        : L10n.string("ui.common.favorite"),
                    systemImage:
                        library.contains(song: result.song)
                            ? "heart.slash"
                            : "heart"
                )
            }
            .tint(.pink)
        }
        .accessibilityHint("ui.recognition.play_from_match_hint")
    }

    private var noMatchView: some View {
        ContentUnavailableView {
            Label(
                "ui.recognition.no_match",
                systemImage: "questionmark.circle"
            )
        } description: {
            Text("ui.recognition.no_match_message")
        } actions: {
            Button(
                "ui.recognition.try_again",
                systemImage: "arrow.clockwise",
                action: startRecognition
            )
            .buttonStyle(.borderedProminent)
        }
    }

    private func failureView(
        _ failure: SongRecognitionFailure
    ) -> some View {
        ContentUnavailableView {
            Label(
                "ui.recognition.failed",
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(failure.message)
        } actions: {
            if failure.opensSystemSettings,
               let settingsURL = URL(
                   string: UIApplication.openSettingsURLString
               ) {
                Button("ui.common.open_system_settings", systemImage: "gear") {
                    openURL(settingsURL)
                }
                .buttonStyle(.borderedProminent)

                Button(
                    "ui.common.retry",
                    systemImage: "arrow.clockwise",
                    action: startRecognition
                )
                .buttonStyle(.bordered)
            } else {
                Button(
                    "ui.common.retry",
                    systemImage: "arrow.clockwise",
                    action: startRecognition
                )
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func progressView(
        title: String,
        description: String
    ) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("ui.common.cancel", role: .cancel) {
                recognition.cancel()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var showsRestartButton: Bool {
        switch recognition.phase {
        case .results, .noMatch, .failed:
            true
        case .ready,
             .requestingPermission,
             .listening,
             .matching:
            false
        }
    }

    private var readyDescription: String {
        let duration = settings.songRecognition.duration
        if settings.songRecognition.audioSource != .microphone {
            let timing = duration.isContinuous
                ? L10n.string("ui.recognition.capture.continuous")
                : L10n.format("ui.recognition.capture.limited", duration.title)
            return settings.songRecognition.audioSource.detail + "\n" + timing
        }
        if duration.isContinuous {
            return L10n.string("ui.recognition.ready.continuous")
        }
        return L10n.format("ui.recognition.ready.limited", duration.title)
    }

    private var audioSourceBinding: Binding<SongRecognitionAudioSource> {
        Binding(
            get: { settings.songRecognition.audioSource },
            set: { settings.songRecognition.audioSource = $0 }
        )
    }

    private func play(_ result: SongRecognitionResult) {
        recognition.prepareForResultPlayback()
        Task {
            await player.play(
                result.song,
                in: recognition.results.map(\.song),
                startAt: result.playbackPosition
            )
        }
    }

    private func startRecognition() {
        if settings.songRecognition.audioSource == .microphone, player.isPlaying {
            player.togglePlayback()
        }
        recognition.start(
            api: api,
            duration: settings.songRecognition.duration,
            source: settings.songRecognition.audioSource
        )
    }
}
