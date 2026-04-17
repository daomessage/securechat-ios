//
//  WelcomeView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI

/// 欢迎屏幕 — 新用户注册或已有用户恢复
struct WelcomeView: View {
    @State var appState: AppState

    var body: some View {
        VStack(spacing: Spacing32) {
            // Logo 区域
            VStack(spacing: Spacing16) {
                ZStack {
                    RoundedRectangle(cornerRadius: RadiusXL)
                        .fill(BlueAccent.opacity(0.15))

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(BlueAccent)
                }
                .frame(width: 80, height: 80)

                VStack(spacing: Spacing8) {
                    Text("DAO MESSAGE")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(TextPrimary)

                    Text("Your keys. Your privacy.\nEnd-to-end encrypted.")
                        .font(.system(size: 15))
                        .foregroundColor(TextMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }

            Spacer()

            // 按钮组
            VStack(spacing: Spacing12) {
                // 新建账户
                Button(action: {
                    // 生成新助记词并跳转
                    let mnemonic = generateMnemonic()
                    appState.route = .generateMnemonic
                    // 临时保存助记词（实际应该在状态管理器中）
                }) {
                    Text("新建账户")
                        .font(.system(size: 16, weight: .semibold))
                }
                .primaryButton()
                .frame(height: Theme.buttonHeight)

                // 恢复账户
                Button(action: {
                    appState.route = .recover
                }) {
                    Text("从助记词恢复")
                        .font(.system(size: 16, weight: .semibold))
                }
                .secondaryButton()
                .frame(height: Theme.buttonHeight)
            }

            // 版本号
            Text("v1.0.0 · Powered by DAO MESSAGE")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(TextMuted)
        }
        .padding(Spacing40)
        .appBackground()
    }

    // MARK: - Private Methods

    private func generateMnemonic() -> String {
        // 实际应调用 SDK 的 KeyDerivation.newMnemonic()
        // 这里为示例
        return "abandon ability able about above absent absolute absorb abstract abuse access accident account accuse achieve acid acoustic acquire across act action actor acts actual acumen acute"
    }
}

#Preview {
    WelcomeView(appState: AppState())
}
