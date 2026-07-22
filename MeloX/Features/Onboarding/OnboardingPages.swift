import SwiftUI

struct OnboardingWelcomeView: View {
    let continueAction: () -> Void
    let showLicenses: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            Image("MeloXLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(.rect(cornerRadius: 25))
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("MeloX")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                Text("用原生方式发现、播放和收藏网易云音乐。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 28)
            .padding(.horizontal, 32)

            Spacer(minLength: 36)

            Text("MeloX 是非官方第三方客户端，与网易云音乐及其关联公司不存在隶属、合作或授权关系。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                Button(action: continueAction) {
                    Text("继续")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

                Button("项目与许可", action: showLicenses)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(.bar)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct OnboardingAccountView: View {
    let profile: AccountProfile?
    let isLoggedIn: Bool
    let login: () -> Void
    let finish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                accountIdentity

                if isLoggedIn {
                    Text("你的收藏歌曲、歌单和播放历史会显示在音乐库中。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    signInBenefits
                }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 32)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                if isLoggedIn {
                    prominentButton("开始使用 MeloX", action: finish)
                } else {
                    prominentButton("登录网易云音乐", action: login)

                    Button("稍后再说", action: finish)
                        .font(.headline)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(.bar)
        }
        .navigationTitle("网易云音乐")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var accountIdentity: some View {
        if isLoggedIn {
            AsyncImage(url: profile?.artworkURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 96, height: 96)
            .background(.quaternary, in: .circle)
            .clipShape(.circle)

            VStack(spacing: 8) {
                Text(profile?.nickname ?? "网易云音乐账号")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Label("已登录", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
        } else {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("连接网易云音乐")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("登录后可以同步个人音乐库并使用账号相关功能。登录并不是开始使用 MeloX 的必要条件。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var signInBenefits: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("同步收藏歌曲、歌单和播放历史", systemImage: "music.note.list")
            Label("访问每日推荐等账号专属内容", systemImage: "sparkles")
            Label("登录 Cookie 仅保存在本机", systemImage: "lock.iphone")
        }
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func prominentButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}
