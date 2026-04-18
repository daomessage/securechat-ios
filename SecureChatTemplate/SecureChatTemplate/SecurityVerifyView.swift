//
//  SecurityVerifyView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import SecureChatSDK

/// 安全码核验视图 - 用于验证 E2EE 对话的真实性，防止 MITM 攻击
struct SecurityVerifyView: View {
    @Binding var isPresented: Bool
    let conversationId: String
    let theirAliasId: String
    @State private var userInput = ""
    @State private var showError = false
    @State private var isVerifying = false
    @State private var mySecurityCode = ""
    @State private var isLoading = true

    private let client = SecureChatClient()

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: Spacing20) {
                HStack {
                    Text("核验安全码")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TextPrimary)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(TextMuted)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing8) {
                    Text("你的安全码 (前 8 位):")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TextMuted)

                    if isLoading {
                        ProgressView()
                            .frame(height: 40)
                    } else {
                        Text(String(mySecurityCode.prefix(8)))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(TextPrimary)
                            .padding(Spacing8)
                            .background(Surface1)
                            .cornerRadius(RadiusSmall)
                            .textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing8) {
                    Text("输入对方的安全码前 8 位:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TextMuted)
                    TextField(
                        "例: A1B2C3D4",
                        text: $userInput
                    )
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(TextPrimary)
                    .textInputAutocapitalization(.characters)
                    .frame(height: Theme.inputHeight)
                    .padding(.horizontal, Spacing12)
                    .background(Surface1)
                    .cornerRadius(RadiusMedium)
                }

                if showError {
                    HStack(spacing: Spacing8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(DangerColor)
                        Text("安全码不匹配，可能存在中间人攻击")
                            .foregroundColor(DangerColor)
                    }
                    .font(.system(size: 13))
                    .padding(Spacing12)
                    .background(DangerColor.opacity(0.1))
                    .cornerRadius(RadiusMedium)
                }

                HStack(spacing: Spacing12) {
                    Button(action: { isPresented = false }) {
                        Text("跳过")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .secondaryButton()
                    .frame(height: Theme.buttonHeight)

                    Button(action: verifyCode) {
                        if isVerifying {
                            ProgressView()
                                .tint(TextPrimary)
                        } else {
                            Text("核验")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .primaryButton()
                    .frame(height: Theme.buttonHeight)
                    .disabled(isVerifying || userInput.isEmpty)
                }

                Spacer()
            }
            .padding(Spacing20)
            .background(Surface1)
            .cornerRadius(RadiusLarge)
            .padding(Spacing20)
            .task {
                await loadSecurityCode()
            }
        }
    }

    /// 从 SDK 加载安全码
    private func loadSecurityCode() async {
        do {
            let secCode = try await client.getSecurityCode(conversationId: conversationId)
            await MainActor.run {
                mySecurityCode = secCode.code
                isLoading = false
            }
        } catch {
            print("加载安全码失败: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    /// 验证安全码
    private func verifyCode() {
        showError = false
        isVerifying = true

        // 比对安全码前 8 位
        let myFirst8 = String(mySecurityCode.prefix(8))
        let theirInput = userInput.uppercased()

        if theirInput == myFirst8 {
            // 验证成功 - 调用 SDK 标记会话已验证
            Task {
                do {
                    // TODO: 确认 SDK API - markSessionVerified
                    // try await client.security.markSessionVerified(conversationId: conversationId)

                    await MainActor.run {
                        isPresented = false
                    }
                } catch {
                    await MainActor.run {
                        showError = true
                        isVerifying = false
                    }
                }
            }
        } else {
            // 验证失败
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showError = true
                isVerifying = false
            }
        }
    }
}

#Preview {
    SecurityVerifyView(
        isPresented: .constant(true),
        conversationId: "conv1",
        theirAliasId: "u12345678"
    )
}
