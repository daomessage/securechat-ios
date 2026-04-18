//
//  RecoverView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import SecureChatSDK

/// 恢复账户屏幕 — 从助记词恢复已有账户
struct RecoverView: View {
    @State var appState: AppState
    @State private var mnemonicInput = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var isValidMnemonic: Bool {
        let words = mnemonicInput.trimmingCharacters(in: .whitespaces).split(separator: " ")
        return words.count == 12 && words.allSatisfy { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: Spacing20) {
            // 顶栏
            HStack {
                Button(action: {
                    appState.route = .welcome
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
                Text("恢复你的账户")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(TextPrimary)

                Text("输入你的 12 个单词恢复账户")
                    .font(.system(size: 14))
                    .foregroundColor(TextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing20)

            Spacer()

            // 输入框
            VStack(alignment: .leading, spacing: Spacing8) {
                Text("助记词 (用空格分隔)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TextMuted)

                TextEditor(text: $mnemonicInput)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(TextPrimary)
                    .padding(.all, Spacing12)
                    .background(Surface1)
                    .cornerRadius(RadiusMedium)
                    .frame(height: 150)
            }
            .padding(.horizontal, Spacing20)

            // 验证提示
            HStack(spacing: Spacing8) {
                if isValidMnemonic {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(SuccessColor)
                    Text("有效的 12 词助记词")
                        .font(.system(size: 13))
                        .foregroundColor(SuccessColor)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(TextMuted)
                    Text("请输入 12 个单词")
                        .font(.system(size: 13))
                        .foregroundColor(TextMuted)
                }
                Spacer()
            }
            .frame(height: 44)
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

            // 恢复按钮
            Button(action: {
                restoreAccount()
            }) {
                if isLoading {
                    ProgressView()
                        .tint(TextPrimary)
                } else {
                    Text("恢复账户")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .primaryButton()
            .frame(height: Theme.buttonHeight)
            .opacity(isValidMnemonic && !isLoading ? 1 : 0.5)
            .disabled(!isValidMnemonic || isLoading)
            .padding(.horizontal, Spacing20)
            .padding(.bottom, Spacing20)
        }
        .appBackground()
    }

    // MARK: - Private Methods

    private func restoreAccount() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let client = SecureChatClient()

                // 验证助记词格式
                guard validateMnemonic(mnemonicInput) else {
                    throw SDKError.invalidMnemonic("无效的 12 词助记词格式")
                }

                // 从助记词恢复账户
                let aliasId = try await client.auth?.loginWithMnemonic(mnemonicInput) ?? ""

                // 建立 WebSocket 连接
                await client.connect()

                // 恢复成功，更新状态并跳转主界面
                await MainActor.run {
                    appState.userInfo = UserInfo(aliasId: aliasId, nickname: "恢复用户")
                    appState.sdkReady = true
                    appState.route = .main
                }
            } catch {
                // 恢复失败
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// 验证助记词格式（BIP39 12 词）
    private func validateMnemonic(_ text: String) -> Bool {
        let words = text.trimmingCharacters(in: .whitespaces).split(separator: " ")
        return words.count == 12 && words.allSatisfy { !$0.isEmpty }
    }
}

#Preview {
    RecoverView(appState: AppState())
}
