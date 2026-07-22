import SwiftUI

struct ProjectLicensesView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        "PV Tool 仅限非商业使用",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.orange)

                    Text("文字 PV 模板、效果实现及相关衍生内容受 PV Tool 单独的 Non-Commercial License 约束。用于商业产品、付费服务或商业化嵌入前，必须另行取得原作者授权。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                NavigationLink("查看完整许可与商业授权说明") {
                    LegalDocumentView(document: .pvTool)
                }
            } header: {
                Text("重要提醒")
            } footer: {
                Text("MeloX 的 GPLv3 许可证不会覆盖或替代 PV Tool 的单独许可条件。")
            }

            Section("许可证") {
                licenseLink(
                    title: "MeloX",
                    license: "GNU GPLv3",
                    document: .melox
                )
                licenseLink(
                    title: "YesPlayMusic",
                    license: "MIT License",
                    document: .yesPlayMusic
                )
                licenseLink(
                    title: "PV Tool",
                    license: "Non-Commercial License",
                    document: .pvTool
                )
                licenseLink(
                    title: "Source Han Serif CN",
                    license: "SIL OFL 1.1",
                    document: .sourceHanSerif
                )
            }

            Section {
                projectLink(
                    name: "jayfunc/BetterLyrics",
                    contribution: "逐字歌词渲染、光效与动效参考",
                    url: URL(string: "https://github.com/jayfunc/BetterLyrics")!
                )
                projectLink(
                    name: "WXRIW/Lyricify-Lyrics-Helper",
                    contribution: "网易云 YRC 逐字歌词解析参考",
                    url: URL(string: "https://github.com/WXRIW/Lyricify-Lyrics-Helper")!
                )
                projectLink(
                    name: "qier222/YesPlayMusic",
                    contribution: "网易云接口与播放器实现参考",
                    url: URL(string: "https://github.com/qier222/YesPlayMusic")!
                )
                projectLink(
                    name: "DanteAlighieri13210914/pv-tool",
                    contribution: "文字 PV 模板与效果的原始实现",
                    url: URL(string: "https://github.com/DanteAlighieri13210914/pv-tool")!
                )
            } header: {
                Text("参考项目")
            } footer: {
                Text("各参考项目的代码、资源和文档仍分别受其原始许可证与声明约束。")
            }

            Section("声明") {
                Text("MeloX 是非官方第三方客户端，与网易云音乐及其关联公司不存在隶属、合作或授权关系。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("项目与许可")
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
    case pvTool
    case sourceHanSerif

    var id: String { rawValue }

    var title: String {
        switch self {
        case .melox: "MeloX 许可证"
        case .yesPlayMusic: "YesPlayMusic 许可证"
        case .pvTool: "PV Tool 许可与声明"
        case .sourceHanSerif: "思源宋体许可证"
        }
    }

    var text: String {
        switch self {
        case .melox:
            "MeloX 应用主体以 GNU General Public License version 3 发布。复制、修改或分发时，应保留版权与许可声明，并遵守 GPLv3 的源代码提供及同许可证分发要求。第三方代码和资源的单独许可证仍然有效。"
        case .yesPlayMusic:
            "MeloX 的网易云接口和播放器实现参考了 qier222/YesPlayMusic。YesPlayMusic 以 MIT License 发布，Copyright © 2020–2023 qier222；使用其软件或重要部分时需保留原版权和许可声明。"
        case .pvTool:
            Self.pvToolText
        case .sourceHanSerif:
            Self.bundledText(named: "SourceHanSerif-LICENSE", extension: "txt")
                ?? "思源宋体使用 SIL Open Font License 1.1。完整许可证随应用资源一同提供。"
        }
    }

    var sourceURL: URL? {
        switch self {
        case .melox:
            URL(string: "https://github.com/youshen2/MeloX/blob/master/LICENSE")
        case .yesPlayMusic:
            URL(string: "https://github.com/qier222/YesPlayMusic/blob/main/LICENSE")
        case .pvTool:
            URL(string: "https://github.com/DanteAlighieri13210914/pv-tool")
        case .sourceHanSerif:
            URL(string: "https://openfontlicense.org/open-font-license-official-text/")
        }
    }

    private static var pvToolText: String {
        let documents = [
            ("PV Tool — Non-Commercial License", "PVTool-LICENSE", "txt"),
            ("NOTICE", "PVTool-NOTICE", "txt"),
            ("Commercial License", "PVTool-COMMERCIAL", "md"),
        ]

        let contents = documents.compactMap { title, name, fileExtension in
            bundledText(named: name, extension: fileExtension).map {
                "\(title)\n\n\($0)"
            }
        }
        guard !contents.isEmpty else {
            return "PV Tool 使用 Non-Commercial License。未经作者书面许可，不得用于商业产品、付费服务或其他商业场景。商业使用需要联系原作者取得单独授权。"
        }
        return contents.joined(separator: "\n\n──────────\n\n")
    }

    private static func bundledText(
        named name: String,
        extension fileExtension: String
    ) -> String? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension
        ) else {
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
                        Label("查看来源", systemImage: "arrow.up.right")
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
