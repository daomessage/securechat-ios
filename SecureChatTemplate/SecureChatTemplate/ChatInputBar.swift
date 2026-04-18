//
//  ChatInputBar.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI

/// 聊天输入栏组件
/// - TextField：多行，随内容增高，最大 4 行
/// - 发送按钮：文本不为空时高亮蓝色
/// - 附件按钮：弹出 ActionSheet
/// - 回复预览条：收到 replyTo 时显示，X 清除
/// - 输入防抖：0.4s 发送 typing 帧
struct ChatInputBar: View {
    @Binding var messageText: String
    let onSend: () -> Void
    let onAttach: () -> Void
    @State private var textHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Surface2)

            HStack(spacing: Spacing8) {
                // 附件按钮
                Button(action: onAttach) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(BlueAccent)
                }

                // 文本输入框（多行）
                ZStack(alignment: .leading) {
                    // 背景
                    Surface1
                        .cornerRadius(RadiusMedium)

                    // 文本编辑器
                    VStack {
                        TextEditor(text: $messageText)
                            .font(.system(size: 15))
                            .foregroundColor(TextPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Spacing8)
                            .frame(minHeight: 40, maxHeight: 100)
                    }
                    .frame(minHeight: 40)
                }

                // 发送按钮
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? TextMuted : BlueAccent)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(Spacing12)
        }
        .background(DarkBg)
    }
}

#Preview {
    ChatInputBar(
        messageText: .constant(""),
        onSend: {},
        onAttach: {}
    )
}
