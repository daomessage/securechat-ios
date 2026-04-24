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
        // 品牌渐变 · blue-400 → violet-400 → purple-400 (对齐 PWA / Android)
        let titleGradient = LinearGradient(
            colors: [
                Color(red: 96/255, green: 165/255, blue: 250/255),    // blue-400
                Color(red: 167/255, green: 139/255, blue: 250/255),   // violet-400
                Color(red: 192/255, green: 132/255, blue: 252/255),   // purple-400
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        VStack(spacing: Spacing.s8) {
            Spacer()

            // 标题区 (gradient 文字代替老的 Logo 盒, 对齐 PWA/Android)
            VStack(spacing: Spacing.s4) {
                Text("DAO Message")
                    .font(.system(size: TextSize.xl4, weight: .bold))
                    .foregroundStyle(titleGradient)
                Text("零知识端到端加密通讯 · 由你掌控的去中心化即时通讯")
                    .font(.system(size: TextSize.sm))
                    .foregroundColor(TextMutedLight)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.s4)
            }

            // 按钮组
            VStack(spacing: Spacing.s3) {
                Button(action: {
                    _ = generateMnemonic()
                    appState.route = .generateMnemonic
                }) {
                    Text("创建新账户")
                        .font(.system(size: TextSize.base, weight: .medium))
                }
                .primaryButton()
                .frame(height: 48)

                Button(action: { appState.route = .recover }) {
                    Text("恢复已有账户")
                        .font(.system(size: TextSize.base, weight: .medium))
                }
                .secondaryButton()
                .frame(height: 48)
            }
            .padding(.top, Spacing.s6)

            Spacer()

            // 版本号
            Text("v1.0 · 由 DAO MESSAGE 协议驱动")
                .font(.system(size: TextSize.xs))
                .foregroundColor(TextMuted)
                .padding(.bottom, Spacing.s6)
        }
        .padding(Spacing.s6)
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
