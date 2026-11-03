import SwiftUI

/// Scroll content can pass under the floating player. This inset only keeps
/// the last row clear once a list is scrolled to the bottom. `HSplitView`
/// does not inherit the page safe-area inset.
private func desktopPlayerScrollContentInset(
    _ model: DesktopAppModel
) -> CGFloat {
    guard model.player.currentSong != nil else { return 0 }
    return model.player.playbackIssue == nil
        ? DesktopBottomPlayerMetrics.regularGlobalInsetHeight
        : DesktopBottomPlayerMetrics.issueGlobalInsetHeight
}

/// `List` and `ScrollView` inside `HSplitView` ignore `contentMargins`, so the
/// end inset has to be real scroll content. It stays under the player until
/// the list is scrolled to the bottom.
@ViewBuilder
private func playerScrollEndSpacer(_ height: CGFloat) -> some View {
    if height > 0 {
        Color.clear
            .frame(height: height)
            .accessibilityHidden(true)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

struct DesktopMessagesView: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var conversations: [NeteasePrivateConversation] = []
    @State private var selectedContact: NeteaseMessageContact?
    @State private var phase: LoadingPhase = .loading
    @State private var isComposing = false

    private var currentUserID: Int { model.library.profile?.id ?? 0 }

    var body: some View {
        Group {
            if !model.library.isLoggedIn {
                ContentUnavailableView {
                    Label("ui.account.login_required", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("ui.desktop.messages.login_message")
                } actions: {
                    Button("ui.common.login") { model.ui.sheet = .login }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                HSplitView {
                    conversationList
                        .frame(minWidth: 270, idealWidth: 330, maxWidth: 410)

                    if let selectedContact {
                        DesktopConversationPane(contact: selectedContact)
                            .id(selectedContact.id)
                    } else {
                        ContentUnavailableView(
                            "ui.desktop.messages.select_conversation",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("ui.desktop.messages.select_conversation.message")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("ui.messages.private.title")
        .toolbar {
            if !model.ui.isNowPlayingPresented {
                ToolbarItemGroup {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help(L10n.string("ui.desktop.messages.refresh"))
                    .disabled(!model.library.isLoggedIn)

                    Button {
                        isComposing = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help(L10n.string("ui.messages.start_private_message"))
                    .disabled(!model.library.isLoggedIn)
                }
            }
        }
        .sheet(isPresented: $isComposing) {
            DesktopNewMessageSheet { contact in
                selectedContact = contact
            }
            .environment(model)
        }
        .task(id: model.settings.cookie) { await load() }
    }

    private var conversationList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ui.desktop.messages.conversations")
                    .font(.title2.bold())
                Spacer()
                Text(conversations.count.formatted(.number.locale(L10n.locale)))
                    .foregroundStyle(.secondary)
            }
            .padding(18)

            Divider()

            List {
                ForEach(conversations) { conversation in
                    let contact = conversation.participant(currentUserID: currentUserID)
                    Button {
                        selectedContact = contact
                        clearUnread(for: contact.id)
                    } label: {
                        HStack(spacing: 11) {
                            DesktopArtworkView(url: contact.artworkURL, cornerRadius: 999)
                                .frame(width: 44, height: 44)
                                .clipShape(.circle)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(contact.displayName)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Spacer()
                                    if conversation.lastMessageTime > 0 {
                                        Text(messageTime(conversation.lastMessageTime))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                HStack {
                                    Text(conversation.lastMessage.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    if conversation.unreadCount > 0 {
                        Text(conversation.unreadCount.formatted(.number.locale(L10n.locale)))
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.red, in: .capsule)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedContact?.id == contact.id
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                }
                playerScrollEndSpacer(desktopPlayerScrollContentInset(model))
            }
            .listStyle(.plain)
            .overlay {
                switch phase {
                case .loading where conversations.isEmpty:
                    Color.clear
                        .desktopLoadingStatus(
                            L10n.string("ui.messages.loading_private_messages"),
                            isPresented: true
                        )
                case .failed(let message) where conversations.isEmpty:
                    ContentUnavailableView(
                        "ui.desktop.messages.load_failed",
                        systemImage: "wifi.exclamationmark",
                        description: Text(message)
                    )
                case .loaded where conversations.isEmpty:
                    ContentUnavailableView(
                        "ui.messages.empty",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("ui.messages.empty.message")
                    )
                default:
                    EmptyView()
                }
            }
        }
    }

    private func load() async {
        guard model.library.isLoggedIn else {
            conversations = []
            phase = .loaded
            return
        }
        phase = .loading
        do {
            conversations = try await model.api.privateMessageConversations()
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func clearUnread(for contactID: Int) {
        guard let index = conversations.firstIndex(where: {
            $0.participant(currentUserID: currentUserID).id == contactID
        }) else { return }
        conversations[index].unreadCount = 0
    }

    private func messageTime(_ milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
        if Calendar.current.isDateInToday(date) {
            return date.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened).locale(L10n.locale)
            )
        }
        return date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)
        )
    }
}

private struct DesktopConversationPane: View {
    @Environment(DesktopAppModel.self) private var model
    let contact: NeteaseMessageContact
    @State private var messages: [NeteasePrivateMessage] = []
    @State private var draft = ""
    @State private var phase: LoadingPhase = .loading
    @State private var isSending = false

    private var currentUserID: Int { model.library.profile?.id ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                DesktopArtworkView(url: contact.artworkURL, cornerRadius: 999)
                    .frame(width: 38, height: 38)
                    .clipShape(.circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.displayName)
                        .font(.headline)
                    if let signature = contact.signature, !signature.isEmpty {
                        Text(signature)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 64)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: messages.count) {
                    guard let id = messages.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
                .overlay {
                    switch phase {
                    case .loading where messages.isEmpty:
                        Color.clear
                            .desktopLoadingStatus(
                                L10n.string("ui.desktop.messages.loading_conversation"),
                                isPresented: true
                            )
                    case .failed(let message) where messages.isEmpty:
                        ContentUnavailableView(
                            "ui.desktop.messages.conversation_failed",
                            systemImage: "wifi.exclamationmark",
                            description: Text(message)
                        )
                    default:
                        EmptyView()
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    L10n.format("ui.desktop.messages.input_to", contact.displayName),
                    text: $draft,
                    axis: .vertical
                )
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    .onSubmit { send() }

                Button(action: send) {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up")
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(14)
            .padding(.bottom, desktopPlayerScrollContentInset(model))
        }
        .task { await load() }
    }

    @ViewBuilder
    private func messageBubble(_ message: NeteasePrivateMessage) -> some View {
        let outgoing = message.isOutgoing(currentUserID: currentUserID)
        HStack {
            if outgoing { Spacer(minLength: 90) }
            VStack(alignment: outgoing ? .trailing : .leading, spacing: 4) {
                if let resource = message.payload.resource {
                    Button {
                        navigate(to: resource)
                    } label: {
                        HStack(spacing: 9) {
                            DesktopArtworkView(url: resource.artworkURL, cornerRadius: 6)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resource.kindTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(resource.title)
                                    .font(.callout.weight(.semibold))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !message.payload.text.isEmpty {
                    Text(message.payload.text)
                        .textSelection(.enabled)
                }
                Text(
                    Date(timeIntervalSince1970: TimeInterval(message.time) / 1_000)
                        .formatted(
                            Date.FormatStyle(date: .omitted, time: .shortened)
                                .locale(L10n.locale)
                        )
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                outgoing ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.11),
                in: .rect(cornerRadius: 13)
            )
            if !outgoing { Spacer(minLength: 90) }
        }
    }

    private func load() async {
        phase = .loading
        do {
            messages = try await model.api.privateMessageHistory(userID: contact.id)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                try await model.api.sendPrivateText(text, to: [contact.id])
                draft = ""
                await load()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func navigate(to resource: NeteaseShareResource) {
        switch resource {
        case .song(let song): model.ui.navigate(to: .song(song.id))
        case .playlist(let playlist): model.ui.navigate(to: .playlist(playlist.id))
        case .album(let album): model.ui.navigate(to: .album(album.id))
        }
    }
}

private struct DesktopNewMessageSheet: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onSelect: (NeteaseMessageContact) -> Void
    @State private var contacts: [NeteaseMessageContact] = []
    @State private var query = ""

    private var filteredContacts: [NeteaseMessageContact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return contacts }
        return contacts.filter {
            $0.displayName.localizedStandardContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ui.messages.start_private_message")
                    .font(.title2.bold())
                Spacer()
                Button("ui.common.done") { dismiss() }
            }
            .padding(20)

            TextField("ui.messages.search_following", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            List(filteredContacts) { contact in
                Button {
                    onSelect(contact)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        DesktopArtworkView(url: contact.artworkURL, cornerRadius: 999)
                            .frame(width: 38, height: 38)
                            .clipShape(.circle)
                        VStack(alignment: .leading) {
                            Text(contact.displayName)
                            if let signature = contact.signature {
                                Text(signature)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 480, height: 600)
        .task {
            let loadingMessage = L10n.string("ui.messages.loading_contacts")
            model.ui.setPresentedLoadingMessage(loadingMessage)
            defer {
                model.ui.clearPresentedLoadingMessage(
                    ifMatching: loadingMessage
                )
            }
            guard let id = model.library.profile?.id else { return }
            contacts = (try? await model.api.messageContacts(userID: id)) ?? []
        }
    }
}
