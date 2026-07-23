import SwiftUI

struct NeteasePrivateMessageView: View {
    let resource: NeteaseShareResource

    @Environment(\.dismiss) private var dismiss
    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library

    @State private var contacts: [NeteaseMessageContact] = []
    @State private var selectedContactIDs: Set<Int> = []
    @State private var message = ""
    @State private var searchQuery = ""
    @State private var phase: LoadingPhase = .loading
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("私信内容") {
                NeteaseShareResourcePreview(resource: resource)

                TextField(
                    "附言（选填）",
                    text: $message,
                    axis: .vertical
                )
                .lineLimit(2...5)
            }

            Section {
                contactsContent
            } header: {
                HStack {
                    Text("收件人")
                    Spacer()
                    if !selectedContactIDs.isEmpty {
                        Text("已选择 \(selectedContactIDs.count) 人")
                    }
                }
            }
        }
        .navigationTitle("网易云私信")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: "搜索关注的人")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
                .disabled(isSending)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("发送")
                    }
                }
                .disabled(selectedContactIDs.isEmpty || isSending)
            }
        }
        .interactiveDismissDisabled(isSending)
        .task {
            await loadContacts()
        }
        .alert(
            "私信发送失败",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "网易云音乐未完成操作。")
        }
    }

    @ViewBuilder
    private var contactsContent: some View {
        switch phase {
        case .loading:
            HStack {
                Spacer()
                ProgressView("正在读取联系人")
                Spacer()
            }
            .listRowBackground(Color.clear)
        case .failed(let message):
            ContentUnavailableView {
                Label("无法读取联系人", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("重试") {
                    Task { await loadContacts() }
                }
            }
            .listRowBackground(Color.clear)
        case .loaded:
            if filteredContacts.isEmpty {
                ContentUnavailableView(
                    searchQuery.isEmpty ? "暂无可用联系人" : "没有找到联系人",
                    systemImage: searchQuery.isEmpty
                        ? "person.2.slash"
                        : "magnifyingglass"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredContacts) { contact in
                    Button {
                        toggleSelection(for: contact)
                    } label: {
                        contactRow(contact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredContacts: [NeteaseMessageContact] {
        let query = searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return contacts }
        return contacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(query)
                || contact.nickname.localizedCaseInsensitiveContains(query)
        }
    }

    private func contactRow(_ contact: NeteaseMessageContact) -> some View {
        HStack(spacing: 12) {
            ArtworkImage(url: contact.artworkURL, cornerRadius: 1_000)
                .frame(width: 44, height: 44)
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let signature = contact.signature?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !signature.isEmpty {
                    Text(signature)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(
                systemName: selectedContactIDs.contains(contact.id)
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .font(.title3)
            .foregroundStyle(
                selectedContactIDs.contains(contact.id)
                    ? Color.accentColor
                    : Color.secondary
            )
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(
            selectedContactIDs.contains(contact.id) ? .isSelected : []
        )
    }

    private func toggleSelection(for contact: NeteaseMessageContact) {
        if selectedContactIDs.contains(contact.id) {
            selectedContactIDs.remove(contact.id)
        } else {
            selectedContactIDs.insert(contact.id)
        }
    }

    private func loadContacts() async {
        guard phase != .loading || contacts.isEmpty else { return }
        phase = .loading

        do {
            let userID: Int
            if let profileID = library.profile?.id {
                userID = profileID
            } else {
                guard library.isLoggedIn else {
                    throw APIError.notLoggedIn
                }
                userID = try await api.accountProfile().id
            }

            contacts = try await api.messageContacts(userID: userID)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func send() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        do {
            try await api.sendPrivateMessage(
                resource,
                to: Array(selectedContactIDs),
                message: message.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
