//
//  ConfirmBackupView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI

/// 确认备份屏幕 — 验证用户已正确记下助记词
struct ConfirmBackupView: View {
    @State var appState: AppState
    @State private var selectedWords: [Int: String] = [:]
    @State private var testWords = [(index: 1, word: "ability"), (index: 5, word: "absent"), (index: 8, word: "abstract")]
    @State private var allWords = ["abandon", "ability", "able", "about", "above", "absent", "absolute", "absorb", "abstract", "abuse", "access", "accident"]

    var isComplete: Bool {
        selectedWords.count == testWords.count &&
        testWords.allSatisfy { selectedWords[$0.index] == $0.word }
    }

    var body: some View {
        VStack(spacing: Spacing20) {
            // 顶栏
            HStack {
                Button(action: {
                    appState.route = .generateMnemonic
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
                Text("验证你的助记词")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(TextPrimary)

                Text("请选择下列位置对应的单词以确认你已正确保存助记词")
                    .font(.system(size: 14))
                    .foregroundColor(TextMuted)
                    .lineSpacing(1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing20)

            Spacer()

            // 验证表单
            VStack(spacing: Spacing16) {
                ForEach(testWords, id: \.index) { test in
                    VStack(alignment: .leading, spacing: Spacing8) {
                        Text("第 \(test.index) 个单词")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TextMuted)

                        Menu {
                            ForEach(allWords, id: \.self) { word in
                                Button(word) {
                                    selectedWords[test.index] = word
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedWords[test.index] ?? "请选择")
                                    .foregroundColor(
                                        selectedWords[test.index] != nil ? TextPrimary : TextMuted
                                    )
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(TextMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.inputHeight)
                            .padding(.horizontal, Spacing12)
                            .background(Surface1)
                            .cornerRadius(RadiusMedium)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing20)

            Spacer()

            // 验证状态提示
            if isComplete {
                HStack(spacing: Spacing8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(SuccessColor)
                    Text("验证成功，继续设置昵称")
                        .font(.system(size: 14))
                        .foregroundColor(SuccessColor)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(SuccessColor.opacity(0.1))
                .cornerRadius(RadiusMedium)
                .padding(.horizontal, Spacing20)
            }

            // 继续按钮
            Button(action: {
                appState.route = .setNickname
            }) {
                Text("继续")
                    .font(.system(size: 16, weight: .semibold))
            }
            .primaryButton()
            .frame(height: Theme.buttonHeight)
            .opacity(isComplete ? 1 : 0.5)
            .disabled(!isComplete)
            .padding(.horizontal, Spacing20)
            .padding(.bottom, Spacing20)
        }
        .appBackground()
    }
}

#Preview {
    ConfirmBackupView(appState: AppState())
}
