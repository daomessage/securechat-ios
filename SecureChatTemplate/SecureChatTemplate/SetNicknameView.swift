//
//  SetNicknameView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import SecureChatSDK

/// 设置昵称屏幕 — 注册账户的最后一步
struct SetNicknameView: View {
    @State var appState: AppState
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var isNicknameValid: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= 20
    }

    var body: some View {
        VStack(spacing: Spacing20) {
            // 顶栏
            HStack {
                Button(action: {
                    appState.route = .confirmBackup
                }) {
                    HStack(spacing: Spacing8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("返回")
                    }
                    .foregroundColor(TextMuted)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing20)
            .padding(.top, Spacing16)

            // 标题
            VStack(alignment: .leading, spacing: Spacing8) {
                Text("设置你的昵称")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(TextPrimary)

                Text("这是其他用户将看到的你的名字")
                    .font(.system(size: 14))
                    .foregroundColor(TextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing20)

            Spacer()

            // 输入框
            VStack(alignment: .leading, spacing: Spacing8) {
                HStack {
                    TextField(
                        "输入昵称 (最多 20 字)",
                        text: $nickname
                    )
                    .font(.system(size: 16))
                    .foregroundColor(TextPrimary)
                    .frame(height: Theme.inputHeight)
                    .padding(.horizontal, Spacing12)
                    .background(Surface1)
                    .cornerRadius(RadiusMedium)

                    if isNicknameValid {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(SuccessColor)
                            .padding(.trailing, Spacing12)
                    }
                }

                HStack {
                    Text("\(nickname.count)/20")
                        .font(.system(size: 12))
                        .foregroundColor(
                            nickname.count > 20 ? DangerColor : TextMuted
                        )
                    Spacer()
                }
                .padding(.horizontal, Spacing12)
            }
            .padding(.horizontal, Spacing20)

            // 错误提示
            if let error = errorMessage {
                HStack(spacing: Spacing8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DangerColor)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(DangerColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing12)
                .background(DangerColor.opacity(0.1))
                .cornerRadius(RadiusMedium)
                .padding(.horizontal, Spacing20)
            }

            Spacer()

            // 开始使用按钮
            Button(action: {
                registerAccount()
            }) {
                if isLoading {
                    ProgressView()
                        .tint(TextPrimary)
                } else {
                    Text("开始使用")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .primaryButton()
            .frame(height: Theme.buttonHeight)
            .opacity(isNicknameValid && !isLoading ? 1 : 0.5)
            .disabled(!isNicknameValid || isLoading)
            .padding(.horizontal, Spacing20)
            .padding(.bottom, Spacing20)
        }
        .appBackground()
    }

    // MARK: - Private Methods

    private func registerAccount() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // 从 AppState 中获取已生成的助记词（需要在路由前保存）
                // TODO: 从 UserDefaults 或 AppState 传递中获取助记词
                let mnemonic = KeyDerivation.newMnemonic()

                let client = SecureChatClient()

                // 调用 SDK 注册账户
                let aliasId = try await client.auth?.registerAccount(mnemonic: mnemonic, nickname: nickname) ?? ""

                // 建立 WebSocket 连接
                await client.connect()

                // 注册成功，更新状态并跳转主界面
                await MainActor.run {
                    appState.userInfo = UserInfo(aliasId: aliasId, nickname: nickname)
                    appState.sdkReady = true
                    appState.route = .main
                }
            } catch {
                // 注册失败
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    SetNicknameView(appState: AppState())
}
