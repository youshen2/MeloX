import SwiftUI

struct ProjectLicensesView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        "ui.legal.pv_tool.noncommercial.title",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.orange)

                    Text("ui.legal.pv_tool.noncommercial.message")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                NavigationLink("ui.legal.pv_tool.view_license") {
                    LegalDocumentView(document: .pvTool)
                }
            } header: {
                Text("ui.legal.section.important")
            } footer: {
                Text("ui.legal.pv_tool.gpl_notice")
            }

            Section("ui.legal.section.licenses") {
                licenseLink(
                    title: "MeloX",
                    license: L10n.string("ui.legal.license.gnu_gpl_v3"),
                    document: .melox
                )
                licenseLink(
                    title: "YesPlayMusic",
                    license: L10n.string("ui.legal.license.mit"),
                    document: .yesPlayMusic
                )
                licenseLink(
                    title: L10n.string("ui.legal.netease_audio_fingerprint"),
                    license: L10n.string("ui.legal.license.mit"),
                    document: .neteaseAPI
                )
                licenseLink(
                    title: "PV Tool",
                    license: L10n.string("ui.legal.license.noncommercial"),
                    document: .pvTool
                )
                licenseLink(
                    title: "Source Han Serif CN",
                    license: L10n.string("ui.legal.license.sil_ofl"),
                    document: .sourceHanSerif
                )
                licenseLink(
                    title: "BeatNet",
                    license: L10n.string("ui.legal.license.cc_by"),
                    document: .beatNet
                )
                licenseLink(
                    title: "UIImageColors",
                    license: L10n.string("ui.legal.license.mit"),
                    document: .uiImageColors
                )
            }

            Section {
                projectLink(
                    name: "jayfunc/BetterLyrics",
                    contribution: L10n.string("ui.legal.reference.better_lyrics"),
                    url: URL(string: "https://github.com/jayfunc/BetterLyrics")!
                )
                projectLink(
                    name: "WXRIW/Lyricify-Lyrics-Helper",
                    contribution: L10n.string("ui.legal.reference.lyricify"),
                    url: URL(string: "https://github.com/WXRIW/Lyricify-Lyrics-Helper")!
                )
                projectLink(
                    name: "qier222/YesPlayMusic",
                    contribution: L10n.string("ui.legal.reference.yesplaymusic"),
                    url: URL(string: "https://github.com/qier222/YesPlayMusic")!
                )
                projectLink(
                    name: "neteasecloudmusicapienhanced/api-enhanced",
                    contribution: L10n.string("ui.legal.reference.netease_api"),
                    url: URL(string: "https://github.com/neteasecloudmusicapienhanced/api-enhanced")!
                )
                projectLink(
                    name: "DanteAlighieri13210914/pv-tool",
                    contribution: L10n.string("ui.legal.reference.pv_tool"),
                    url: URL(string: "https://github.com/DanteAlighieri13210914/pv-tool")!
                )
                projectLink(
                    name: "mjhydri/BeatNet",
                    contribution: L10n.string("ui.legal.reference.beatnet"),
                    url: URL(string: "https://github.com/mjhydri/BeatNet")!
                )
            } header: {
                Text("ui.legal.section.references")
            } footer: {
                Text("ui.legal.references.footer")
            }

            Section("ui.legal.section.disclaimer") {
                Text("ui.legal.unofficial_disclaimer")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ui.legal.projects_licenses.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func licenseLink(
        title: String,
        license: String,
        document: LegalDocument
    ) -> some View {
        NavigationLink {
            LegalDocumentView(document: document)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(license)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func projectLink(
        name: String,
        contribution: String,
        url: URL
    ) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .foregroundStyle(.primary)
                    Text(contribution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
    }
}

enum LegalDocument: String, Identifiable {
    case melox
    case yesPlayMusic
    case neteaseAPI
    case pvTool
    case sourceHanSerif
    case beatNet
    case uiImageColors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .melox: L10n.string("ui.legal.document.melox.title")
        case .yesPlayMusic: L10n.string("ui.legal.document.yesplaymusic.title")
        case .neteaseAPI: L10n.string("ui.legal.document.netease_api.title")
        case .pvTool: L10n.string("ui.legal.document.pv_tool.title")
        case .sourceHanSerif: L10n.string("ui.legal.document.source_han_serif.title")
        case .beatNet: L10n.string("ui.legal.document.beatnet.title")
        case .uiImageColors: "UIImageColors"
        }
    }

    var text: String {
        switch self {
        case .melox:
            L10n.string("ui.legal.document.melox.fallback")
        case .yesPlayMusic:
            L10n.string("ui.legal.document.yesplaymusic.fallback")
        case .neteaseAPI:
            Self.neteaseAPIText
        case .pvTool:
            Self.pvToolText
        case .sourceHanSerif:
            Self.bundledText(named: "SourceHanSerif-LICENSE", extension: "txt")
                ?? L10n.string("ui.legal.document.source_han_serif.fallback")
        case .beatNet:
            Self.bundledText(
                named: "BeatNet-NOTICE",
                extension: "md"
            )
                ?? L10n.string("ui.legal.document.beatnet.fallback")
        case .uiImageColors:
            Self.bundledText(named: "UIImageColors-LICENSE", extension: "txt")
                ?? "MIT License · Copyright (c) 2015 Jathu Satkunarajah"
        }
    }

    var sourceURL: URL? {
        switch self {
        case .melox:
            URL(string: "https://github.com/youshen2/MeloX/blob/master/LICENSE")
        case .yesPlayMusic:
            URL(string: "https://github.com/qier222/YesPlayMusic/blob/main/LICENSE")
        case .neteaseAPI:
            URL(string: "https://github.com/neteasecloudmusicapienhanced/api-enhanced")
        case .pvTool:
            URL(string: "https://github.com/DanteAlighieri13210914/pv-tool")
        case .sourceHanSerif:
            URL(string: "https://openfontlicense.org/open-font-license-official-text/")
        case .beatNet:
            URL(string: "https://github.com/mjhydri/BeatNet")
        case .uiImageColors:
            URL(string: "https://github.com/jathu/UIImageColors/blob/f064be8ee0b03158e61135e6c384aee18d7a5414/LICENSE")
        }
    }

    private static var pvToolText: String {
        let documents = [
            (L10n.string("ui.legal.document.pv_tool.noncommercial_heading"), "PVTool-LICENSE", "txt"),
            (L10n.string("ui.legal.document.notice_heading"), "PVTool-NOTICE", "txt"),
            (L10n.string("ui.legal.document.commercial_heading"), "PVTool-COMMERCIAL", "md"),
        ]

        let contents = documents.compactMap { title, name, fileExtension in
            bundledText(named: name, extension: fileExtension).map {
                "\(title)\n\n\($0)"
            }
        }
        guard !contents.isEmpty else {
            return L10n.string("ui.legal.document.pv_tool.fallback")
        }
        return contents.joined(separator: "\n\n──────────\n\n")
    }

    private static var neteaseAPIText: String {
        let documents = [
            (
                L10n.string("ui.legal.document.audio_fingerprint_notice_heading"),
                "NeteaseAudioFingerprint-NOTICE",
                "txt"
            ),
            (
                L10n.string("ui.legal.license.mit"),
                "NeteaseAPI-LICENSE",
                "txt"
            ),
        ]
        let contents = documents.compactMap {
            title,
            name,
            fileExtension in
            bundledText(
                named: name,
                extension: fileExtension
            ).map {
                "\(title)\n\n\($0)"
            }
        }
        guard !contents.isEmpty else {
            return L10n.string("ui.legal.document.netease_api.fallback")
        }
        return contents.joined(separator: "\n\n──────────\n\n")
    }

    private static func bundledText(
        named name: String,
        extension fileExtension: String
    ) -> String? {
        let candidateURLs = [
            Bundle.main.url(
                forResource: name,
                withExtension: fileExtension
            ),
            Bundle.main.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: "AudioFingerprint"
            ),
            Bundle.main.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: "Resources/AudioFingerprint"
            ),
        ]
        guard let url = candidateURLs.compactMap({ $0 }).first else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            Text(document.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let sourceURL = document.sourceURL {
                ToolbarItem(placement: .primaryAction) {
                    Link(destination: sourceURL) {
                        Label("ui.legal.view_source", systemImage: "arrow.up.right")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectLicensesView()
    }
}
