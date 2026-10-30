import SwiftUI

struct PlaylistCreationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let create: (String, Bool) async throws -> Void

    @State private var name = ""
    @State private var isPrivate = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("ui.playlists.create.name", text: $name)
                Toggle("ui.playlists.create.private", isOn: $isPrivate)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .disabled(isSaving)
            .navigationTitle("ui.playlists.create.title")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ui.common.cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("ui.playlists.create.action")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        #if os(macOS)
        .frame(width: 420, height: 280)
        #endif
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await create(name.trimmingCharacters(in: .whitespacesAndNewlines), isPrivate)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
