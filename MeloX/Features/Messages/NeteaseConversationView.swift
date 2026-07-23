import SwiftUI

struct NeteaseConversationView: View {
    let contact: NeteaseMessageContact
    var onMarkedRead: () -> Void = {}

    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library

    @State private var messages: [NeteasePrivateMessage] = []
    @State private var resolvedSongArtworkURLs: [Int: URL] = [:]
    @State private var currentUserID = 0
    @State private var draft = ""
    @State private var phase: LoadingPhase = .loading
    @State private var isSending = false
    @State private var sendError: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .refreshable {
                await load()
            }
            .onChange(of: messages.last?.id) { _, messageID in
                guard let messageID else { return }
                withAnimation {
                    proxy.scrollTo(messageID, anchor: .bottom)
                }
            }
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .overlay {
            switch phase {
            case .loading where messages.isEmpty:
                ProgressView("正在读取私信")
            case .failed(let message) where messages.isEmpty:
                ConnectionUnavailableView(message: message) {
                    Task { await load() }
                }
            case .loaded where messages.isEmpty:
                ContentUnavailableView(
                    "还没有消息",
                    systemImage: "bubble.left",
                    description: Text("在下方输入内容即可发起私信。")
                )
            default:
                EmptyView()
            }
        }
        .task(id: contact.id) {
            await load()
        }
        .alert(
            "发送失败",
            isPresented: Binding(
                get: { sendError != nil },
                set: { if !$0 { sendError = nil } }
            )
        ) {
            Button("好", role: .cancel) {
                sendError = nil
            }
        } message: {
            Text(sendError ?? "网易云音乐未完成操作。")
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("输入私信", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    send()
                }

            Button {
                send()
            } label: {
                if isSending {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
            }
            .disabled(trimmedDraft.isEmpty || isSending)
            .accessibilityLabel("发送")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func messageRow(_ message: NeteasePrivateMessage) -> some View {
        let isOutgoing = message.isOutgoing(currentUserID: currentUserID)
        return HStack {
            if isOutgoing {
                Spacer(minLength: 56)
            }

            VStack(
                alignment: isOutgoing ? .trailing : .leading,
                spacing: 5
            ) {
                messageContent(message.payload, isOutgoing: isOutgoing)

                if message.time > 0 {
                    Text(messageTime(message.time))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !isOutgoing {
                Spacer(minLength: 56)
            }
        }
    }

    @ViewBuilder
    private func messageContent(
        _ payload: NeteasePrivateMessagePayload,
        isOutgoing: Bool
    ) -> some View {
        if let resource = payload.resource {
            NavigationLink(value: musicRoute(for: resource)) {
                VStack(alignment: .leading, spacing: 7) {
                    if !payload.text.isEmpty {
                        Text(payload.text)
                            .foregroundStyle(isOutgoing ? .white : .primary)
                    }

                    HStack(spacing: 9) {
                        ArtworkImage(
                            url: artworkURL(for: resource),
                            cornerRadius: 6
                        )
                        .id(artworkURL(for: resource))
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(resource.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(resource.kindTitle)
                                .font(.caption)
                                .foregroundStyle(
                                    isOutgoing
                                        ? AnyShapeStyle(.white.opacity(0.75))
                                        : AnyShapeStyle(.secondary)
                                )
                        }
                    }
                }
                .padding(10)
                .background(
                    isOutgoing
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(.quaternary),
                    in: .rect(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
        } else {
            Text(payload.summary)
                .foregroundStyle(isOutgoing ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    isOutgoing
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(.quaternary),
                    in: .rect(cornerRadius: 14)
                )
        }
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func messageTime(_ milliseconds: Int64) -> String {
        Date(
            timeIntervalSince1970: TimeInterval(milliseconds) / 1_000
        )
        .formatted(date: .abbreviated, time: .shortened)
    }

    private func musicRoute(
        for resource: NeteaseShareResource
    ) -> MusicRoute {
        switch resource {
        case .song(let song):
            .song(song)
        case .playlist(let playlist):
            .playlist(playlist)
        case .album(let album):
            .album(album)
        }
    }

    private func artworkURL(for resource: NeteaseShareResource) -> URL? {
        guard case .song(let song) = resource else {
            return resource.artworkURL
        }
        return resolvedSongArtworkURLs[song.id] ?? resource.artworkURL
    }

    private func load() async {
        phase = .loading
        do {
            if let profileID = library.profile?.id {
                currentUserID = profileID
            } else {
                currentUserID = try await api.accountProfile().id
            }
            let loadedMessages = try await api.privateMessageHistory(
                userID: contact.id
            )
            messages = loadedMessages
            phase = .loaded
            onMarkedRead()
            await resolveSongArtwork(in: loadedMessages)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func resolveSongArtwork(
        in messages: [NeteasePrivateMessage]
    ) async {
        let songIDs = Set(
            messages.compactMap { message -> Int? in
                guard case .song(let song) = message.payload.resource,
                      song.id > 0,
                      resolvedSongArtworkURLs[song.id] == nil else {
                    return nil
                }
                return song.id
            }
        )
        guard !songIDs.isEmpty else { return }

        do {
            let songs = try await api.songDetails(ids: Array(songIDs))
            guard !Task.isCancelled else { return }
            for song in songs {
                if let artworkURL = song.album?.artworkURL {
                    resolvedSongArtworkURLs[song.id] = artworkURL
                }
            }
        } catch is CancellationError {
            return
        } catch {
            // 封面补全失败不应影响私信正文和卡片本身的展示。
        }
    }

    private func send() {
        let content = trimmedDraft
        guard !content.isEmpty, !isSending else { return }

        isSending = true
        Task {
            defer { isSending = false }
            do {
                try await api.sendPrivateText(content, to: [contact.id])
                draft = ""
                await load()
            } catch is CancellationError {
                return
            } catch {
                sendError = error.localizedDescription
            }
        }
    }
}
