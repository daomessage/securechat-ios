//
//  MessageBubble.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import AVFoundation
import SecureChatSDK

/// 消息气泡组件
/// - 自己：右侧，蓝色背景，白色文字
/// - 对方：左侧，深灰背景，白色文字
/// - 支持文本、图片、语音、文件类型
/// - 显示时间戳和消息状态图标
struct MessageBubble: View {
    let message: StoredMessage
    let onRetract: (String) -> Void
    var replyPreview: StoredMessage? = nil
    var onReply: ((StoredMessage) -> Void)? = nil
    @State private var showContextMenu = false

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing8) {
            if message.isMe { Spacer() }

            VStack(alignment: message.isMe ? .trailing : .leading, spacing: Spacing4) {
                // 被回复消息预览
                if message.replyToId != nil {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(BlueAccent)
                            .frame(width: 2, height: 28)
                            .cornerRadius(1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(replyPreview.map { $0.isMe ? "你" : "回复" } ?? "回复")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(BlueAccent)
                            Text(replyPreview?.text.prefix(60).description ?? "原消息")
                                .font(.system(size: 11))
                                .foregroundColor(TextMuted)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, Spacing8)
                    .padding(.vertical, 6)
                    .background(Surface2)
                    .cornerRadius(RadiusSmall)
                }

                // 消息内容
                switch message.msgType?.lowercased() ?? "text" {
                case "image":
                    // 图片消息
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Surface1)
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(TextMuted)
                    }
                    .frame(height: 200)
                case "voice":
                    VoiceMessagePlayer(message: message, isMe: message.isMe)
                case "file":
                    // 文件消息
                    HStack(spacing: Spacing8) {
                        Image(systemName: "doc")
                            .font(.system(size: 12))
                            .foregroundColor(message.isMe ? TextPrimary : TextPrimary)
                        Text(message.caption ?? "文件")
                            .font(.system(size: 13))
                            .foregroundColor(message.isMe ? TextPrimary : TextPrimary)
                    }
                    .padding(.horizontal, Spacing12)
                    .padding(.vertical, Spacing8)
                    .background(message.isMe ? BlueAccent : Surface1)
                    .cornerRadius(12)
                case "text", "":
                    // 文本消息
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundColor(message.isMe ? TextPrimary : TextPrimary)
                        .padding(.horizontal, Spacing12)
                        .padding(.vertical, Spacing8)
                        .background(message.isMe ? BlueAccent : Surface1)
                        .cornerRadius(12)
                default:
                    // 未知消息类型 — 协议降级提示（§4.2）
                    VStack(alignment: .leading, spacing: 4) {
                        Text("不支持的消息类型：\(message.msgType ?? "unknown")")
                            .font(.system(size: 13))
                            .foregroundColor(TextMuted)
                        Text("请更新 App 以查看此消息")
                            .font(.system(size: 11))
                            .foregroundColor(BlueAccent)
                    }
                    .padding(.horizontal, Spacing12)
                    .padding(.vertical, Spacing8)
                    .background(Surface1)
                    .cornerRadius(12)
                }

                // 时间戳和状态
                HStack(spacing: Spacing4) {
                    Text(formatTime(message.time))
                        .font(.system(size: 11))
                        .foregroundColor(TextMuted)

                    if message.isMe {
                        switch message.status {
                        case .sending:
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(TextMuted)
                        case .sent:
                            Image(systemName: "checkmark")
                                .font(.system(size: 10))
                                .foregroundColor(TextMuted)
                        case .delivered:
                            HStack(spacing: 0) {
                                Image(systemName: "checkmark")
                                Image(systemName: "checkmark")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(TextMuted)
                        case .read:
                            HStack(spacing: 0) {
                                Image(systemName: "checkmark")
                                Image(systemName: "checkmark")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(BlueAccent)
                        case .failed:
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(DangerColor)
                        }
                    }
                }
                .padding(.horizontal, Spacing12)
            }
            .contextMenu {
                if message.isMe {
                    Button(role: .destructive) {
                        onRetract(message.id)
                    } label: {
                        Label("撤回", systemImage: "xmark.circle")
                    }
                }

                Button {
                    onReply?(message)
                } label: {
                    Label("回复", systemImage: "arrowshape.turn.up.left")
                }

                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }

                Button {
                    showContextMenu = true // triggers details sheet
                } label: {
                    Label("详情", systemImage: "info.circle")
                }
            }
            .sheet(isPresented: $showContextMenu) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Message Details")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TextPrimary)
                    Divider()
                    DetailLine(label: "ID", value: message.id)
                    DetailLine(label: "Time", value: formatDetailTime(message.time))
                    DetailLine(label: "Status", value: "\(message.status)")
                    DetailLine(label: "From", value: message.isMe ? "You" : (message.fromAliasId ?? "Peer"))
                    DetailLine(label: "Type", value: message.msgType ?? "text")
                    if let seq = message.seq { DetailLine(label: "Seq", value: "\(seq)") }
                    if let replyTo = message.replyToId { DetailLine(label: "Reply to", value: replyTo) }
                    Spacer()
                }
                .padding(20)
                .background(DarkBg)
                .presentationDetents([.medium])
            }

            if !message.isMe { Spacer() }
        }
        .animation(.easeInOut(duration: 0.2), value: message.status)
    }

    private func formatTime(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDetailTime(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

private struct DetailLine: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(TextMuted)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(TextPrimary)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    VStack(spacing: Spacing16) {
        MessageBubble(
            message: StoredMessage(
                id: "1",
                conversationId: "conv1",
                text: "这是一条发送的消息",
                isMe: true,
                time: Int64(Date().timeIntervalSince1970 * 1000),
                status: .read
            ),
            onRetract: { _ in }
        )

        MessageBubble(
            message: StoredMessage(
                id: "2",
                conversationId: "conv1",
                text: "这是一条接收的消息",
                isMe: false,
                time: Int64(Date().timeIntervalSince1970 * 1000),
                status: .read
            ),
            onRetract: { _ in }
        )
    }
    .padding(Spacing16)
    .background(DarkBg)
}

/// 语音消息播放器 — 点击下载 + 解密 + AVAudioPlayer 播放
struct VoiceMessagePlayer: View {
    let message: StoredMessage
    let isMe: Bool

    @State private var isPlaying = false
    @State private var isLoading = false
    @State private var player: AVAudioPlayer? = nil

    private var durationText: String {
        if let cap = message.caption, let ms = Int(cap) {
            return "\(ms / 1000)″"
        }
        return "Voice"
    }

    var body: some View {
        HStack(spacing: Spacing8) {
            ZStack {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 28, height: 28)
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.6)
                } else {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            }
            Text(durationText)
                .font(.system(size: 13))
                .foregroundColor(.white)
            HStack(spacing: 2) {
                ForEach([6, 10, 8, 12, 6, 10, 8], id: \.self) { h in
                    Rectangle().fill(Color.white.opacity(0.6))
                        .frame(width: 2, height: CGFloat(h))
                }
            }
        }
        .padding(.horizontal, Spacing12)
        .padding(.vertical, Spacing8)
        .background(isMe ? BlueAccent : Surface1)
        .cornerRadius(12)
        .onTapGesture { handleTap() }
    }

    private func handleTap() {
        if isPlaying {
            player?.stop()
            isPlaying = false
            return
        }
        if let p = player {
            p.play()
            isPlaying = true
            return
        }
        guard let url = message.mediaUrl else { return }
        isLoading = true
        Task {
            do {
                let client = SecureChatClient.shared()
                guard let mediaMgr = client.media else { return }
                // 对标 Android: client.downloadMedia(convId, url)
                let cleanKey = url.replacingOccurrences(of: "[voice]", with: "")
                    .replacingOccurrences(of: "[img]", with: "")
                    .replacingOccurrences(of: "[file]", with: "")
                let data = try await mediaMgr.downloadDecryptedMedia(
                    mediaKey: cleanKey,
                    conversationId: message.conversationId
                )
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("voice_play_\(message.id).m4a")
                try data.write(to: tmpURL)

                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                let p = try AVAudioPlayer(contentsOf: tmpURL)
                p.prepareToPlay()
                p.play()
                await MainActor.run {
                    player = p
                    isPlaying = true
                    isLoading = false
                }
                // 播放完自动重置（AVAudioPlayer 没有内置 delegate for SwiftUI，轮询 duration）
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(p.duration * 1_000_000_000))
                    await MainActor.run { isPlaying = false }
                }
            } catch {
                print("播放语音失败：\(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}
