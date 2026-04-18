//
//  GenerateMnemonicView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import SecureChatSDK

/// 生成助记词屏幕 — 展示 12 个词，要求用户备份
struct GenerateMnemonicView: View {
    @State var appState: AppState
    @State private var mnemonic: String = ""
    @State private var hasBackedUp = false
    @State private var showCopyAlert = false

    // 在 onAppear 时生成助记词
    var onAppearTask: Void {
        if mnemonic.isEmpty {
            // 从 SDK 生成新的 BIP39 助记词
            mnemonic = KeyDerivation.newMnemonic()
        }
        return ()
    }

    var words: [String] {
        mnemonic.split(separator: " ").map(String.init)
    }

    var body: some View {
        VStack(spacing: Spacing20) {
            // 顶栏 - 返回按钮
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
            .onAppear {
                let _ = onAppearTask
            }

            // 标题
            Text("你的恢复短语")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(TextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing20)

            // 警告卡片
            HStack(spacing: Spacing8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DangerColor)

                Text("将这 12 个单词按顺序记下来。永远不要与任何人分享。只有这 12 个词才能恢复你的账户。")
                    .font(.system(size: 13))
                    .foregroundColor(DangerColor)
                    .lineSpacing(1.5)
            }
            .padding(Spacing12)
            .background(DangerColor.opacity(0.1))
            .cornerRadius(RadiusMedium)
            .padding(.horizontal, Spacing20)

            // 词语网格 (3 列)
            VStack(spacing: Spacing8) {
                let columns = [
                    GridItem(.flexible(), spacing: Spacing8),
                    GridItem(.flexible(), spacing: Spacing8),
                    GridItem(.flexible(), spacing: Spacing8)
                ]

                LazyVGrid(columns: columns, spacing: Spacing8) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        VStack(alignment: .leading, spacing: Spacing4) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(TextMuted)

                            Text(word)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(TextPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing10)
                        .background(Surface1)
                        .cornerRadius(RadiusSmall)
                    }
                }
            }
            .padding(.horizontal, Spacing20)

            Spacer()

            // 复制按钮
            Button(action: {
                let item: [String: Any] = [UIPasteboard.typeAutomatic: mnemonic]
                UIPasteboard.general.setItems([item], options: [
                    .expirationDate: Date().addingTimeInterval(60),
                    .localOnly: true,
                ])
                showCopyAlert = true
            }) {
                HStack(spacing: Spacing8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                    Text("复制助记词")
                }
                .font(.system(size: 14, weight: .semibold))
            }
            .secondaryButton()
            .frame(height: Theme.inputHeight)
            .padding(.horizontal, Spacing20)

            // 确认备份复选框
            HStack(spacing: Spacing8) {
                Image(systemName: hasBackedUp ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(hasBackedUp ? BlueAccent : TextMuted)
                    .onTapGesture {
                        hasBackedUp.toggle()
                    }

                Text("我已安全保存我的助记词")
                    .font(.system(size: 14))
                    .foregroundColor(TextMuted)

                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, Spacing20)

            // 继续按钮
            Button(action: {
                appState.route = .confirmBackup
            }) {
                Text("我已安全保存")
                    .font(.system(size: 16, weight: .semibold))
            }
            .primaryButton()
            .frame(height: Theme.buttonHeight)
            .opacity(hasBackedUp ? 1 : 0.5)
            .disabled(!hasBackedUp)
            .padding(.horizontal, Spacing20)
            .padding(.bottom, Spacing20)
        }
        .appBackground()
        .alert("已复制", isPresented: $showCopyAlert) {
            Button("确定") {}
        } message: {
            Text("助记词已复制到剪贴板，请妥善保管。")
        }
    }
}

#Preview {
    GenerateMnemonicView(appState: AppState())
}
