//
//  ChatView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import SecureChatSDK

/// 聊天界面 — 显示会话消息、输入栏等
struct ChatView: View {
    @State var appState: AppState
    let conversationId: String
    @State private var messages: [StoredMessage] = []
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var showSecurityVerify = false
    @State private var isLoading = true
    @State private var theirNickname = "Unknown"
    @State private var theirAliasId = ""
    @State private var errorMessage: String? = nil
    @State private var isLoadingMore = false
    @State private var hasMoreHistory = true
    @State private var showAttachmentPlaceholder = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showFilePicker = false
    @State private var showVoiceRecorder = false
    @State private var voiceRecorder = VoiceRecorder()
    @State private var replyTarget: StoredMessage? = nil
    private let pageSize = 30

    private let client = SecureChatClient.shared()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 聊天顶栏
                ChatHeaderBar(
                    nickname: theirNickname,
                    aliasId: theirAliasId,
                    onClose: {
                        appState.activeChatId = nil
                    },
                    onAudioCall: {
                        guard !theirAliasId.isEmpty else { return }
                        CallManager.shared.call(to: theirAliasId, mode: .audio)
                    },
                    onVideoCall: {
                        guard !theirAliasId.isEmpty else { return }
                        CallManager.shared.call(to: theirAliasId, mode: .video)
                    }
                )

                // 消息列表
                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(BlueAccent)
                        Text("加载消息中...")
                            .font(.system(size: 14))
                            .foregroundColor(TextMuted)
                            .padding(.top, Spacing8)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: Spacing8) {
                                if hasMoreHistory && !messages.isEmpty {
                                    Button(action: { Task { await loadMoreHistory() } }) {
                                        HStack(spacing: 6) {
                                            if isLoadingMore {
                                                ProgressView().tint(BlueAccent)
                                            } else {
                                                Text("加载更多")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(BlueAccent)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                    }
                                    .disabled(isLoadingMore)
                                }
                                if messages.isEmpty {
                                    VStack(spacing: Spacing8) {
                                        Text("暂无消息")
                                            .font(.system(size: 16))
                                            .foregroundColor(TextMuted)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    ForEach(messages, id: \.id) { message in
                                        MessageBubble(
                                            message: message,
                                            onRetract: { msgId in retractMessage(msgId) },
                                            replyPreview: message.replyToId.flatMap { rid in
                                                messages.first(where: { $0.id == rid })
                                            },
                                            onReply: { msg in
                                                replyTarget = msg
                                            }
                                        )
                                        .id(message.id)
                                    }
                                }
                            }
                            .padding(Spacing16)
                            .onChange(of: messages.count) { _, _ in
                                if let lastId = messages.last?.id {
                                    withAnimation {
                                        scrollProxy.scrollTo(lastId, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                }

                // 正在输入指示
                if isTyping {
                    HStack(spacing: Spacing4) {
                        Text("对方正在输入")
                            .font(.system(size: 12))
                            .foregroundColor(TextMuted)
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing16)
                    .padding(.vertical, Spacing8)
                }

                // Reply preview
                if let reply = replyTarget {
                    HStack(spacing: 8) {
                        Rectangle().fill(BlueAccent).frame(width: 2, height: 32).cornerRadius(1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reply.isMe ? "回复自己" : "回复")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(BlueAccent)
                            Text(reply.text.prefix(60).description)
                                .font(.system(size: 12))
                                .foregroundColor(TextMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: { replyTarget = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(TextMuted)
                        }
                    }
                    .padding(.horizontal, Spacing16)
                    .padding(.vertical, Spacing8)
                    .background(Surface1)
                }

                // 输入栏
                ChatInputBar(
                    messageText: $messageText,
                    onSend: {
                        sendMessage()
                    },
                    onAttach: {
                        showAttachmentPlaceholder = true
                    }
                )
            }
            .background(DarkBg)
            .task {
                await loadMessages()
            }
            .confirmationDialog("发送附件", isPresented: $showAttachmentPlaceholder, titleVisibility: .visible) {
                PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                    Text("照片")
                }
                Button("文件") { showFilePicker = true }
                Button("语音") {
                    Task {
                        let granted = await voiceRecorder.requestPermission()
                        await MainActor.run {
                            if granted {
                                showVoiceRecorder = true
                            } else {
                                errorMessage = "麦克风权限被拒绝"
                            }
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showVoiceRecorder) {
                VoiceRecorderSheet(
                    recorder: voiceRecorder,
                    onCancel: {
                        voiceRecorder.cancel()
                        showVoiceRecorder = false
                    },
                    onSend: { data, durationMs in
                        showVoiceRecorder = false
                        Task {
                            do {
                                try await client.sendVoice(
                                    conversationId: conversationId,
                                    toAliasId: theirAliasId,
                                    audioData: data,
                                    durationMs: durationMs
                                )
                                await loadMessages()
                            } catch {
                                await MainActor.run { errorMessage = "发送语音失败：\(error.localizedDescription)" }
                            }
                        }
                    }
                )
                .presentationDetents([.medium])
            }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await sendPhotoFromPicker(newItem) }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleFileImport(result) }
            }

            // 安全码核验 Modal
            if showSecurityVerify {
                SecurityVerifyModalView(isPresented: $showSecurityVerify)
            }

            // 错误提示
            if let error = errorMessage {
                VStack {
                    HStack(spacing: Spacing8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(DangerColor)
                        Text(error)
                            .foregroundColor(DangerColor)
                        Spacer()
                        Button(action: { errorMessage = nil }) {
                            Image(systemName: "xmark")
                                .foregroundColor(DangerColor)
                        }
                    }
                    .padding(Spacing12)
                    .background(DangerColor.opacity(0.1))
                    .cornerRadius(RadiusMedium)
                    .padding(Spacing16)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    // MARK: - Private Methods

    private func loadMessages() async {
        do {
            // 从 SDK 加载历史消息
            let history = try await client.getHistory(conversationId: conversationId, limit: pageSize, before: nil)
            await MainActor.run {
                messages = history
                hasMoreHistory = history.count == pageSize
                isLoading = false
            }

            // 设置消息监听器
            await setupMessageListener()
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 设置消息 + 状态变更监听器，实时接收新消息和状态更新
    private func setupMessageListener() async {
        _ = await client.onMessage { [appState] msg in
            Task { @MainActor in
                if msg.conversationId == conversationId {
                    // 新消息属于当前会话，添加到列表
                    if !messages.contains(where: { $0.id == msg.id }) {
                        messages.append(msg)
                    }
                    // 标记为已读
                    if let maxSeq = msg.seq {
                        Task {
                            await client.markAsRead(conversationId: conversationId, maxSeq: maxSeq, toAliasId: theirAliasId)
                        }
                    }
                }
            }
        }

        // 监听状态变更（sent → delivered → read）
        _ = await client.onStatusChange { change in
            Task { @MainActor in
                if let idx = messages.firstIndex(where: { $0.id == change.messageId }) {
                    let old = messages[idx]
                    // status 为 let，重建 struct
                    let updated = StoredMessage(
                        id: old.id,
                        conversationId: old.conversationId,
                        text: old.text,
                        isMe: old.isMe,
                        time: old.time,
                        status: change.status,
                        msgType: old.msgType,
                        mediaUrl: old.mediaUrl,
                        caption: old.caption,
                        seq: old.seq,
                        fromAliasId: old.fromAliasId,
                        replyToId: old.replyToId
                    )
                    messages[idx] = updated
                }
            }
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = messageText
        messageText = ""
        let replyId = replyTarget?.id
        replyTarget = nil

        Task {
            do {
                // 调用 SDK 发送消息
                let msgId = try await client.sendMessage(
                    conversationId: conversationId,
                    toAliasId: theirAliasId,
                    text: text,
                    replyToId: replyId
                )

                // 创建本地消息显示
                let newMessage = StoredMessage(
                    id: msgId,
                    conversationId: conversationId,
                    text: text,
                    isMe: true,
                    time: Int64(Date().timeIntervalSince1970 * 1000),
                    status: .sending
                )

                await MainActor.run {
                    messages.append(newMessage)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// 从 PhotosPicker 选完图后上传发送
    private func sendPhotoFromPicker(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            try await client.sendImage(conversationId: conversationId, toAliasId: theirAliasId, imageData: data)
            await loadMessages()
            await MainActor.run { photoPickerItem = nil }
        } catch {
            await MainActor.run { errorMessage = "发送图片失败：\(error.localizedDescription)" }
        }
    }

    /// 文件导入回调
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let started = url.startAccessingSecurityScopedResource()
            defer { if started { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let name = url.lastPathComponent
                try await client.sendFile(conversationId: conversationId, toAliasId: theirAliasId, fileData: data, fileName: name)
                await loadMessages()
            } catch {
                await MainActor.run { errorMessage = "发送文件失败：\(error.localizedDescription)" }
            }
        case .failure(let err):
            await MainActor.run { errorMessage = "选择文件失败：\(err.localizedDescription)" }
        }
    }

    /// 加载更早的历史消息（分页）
    private func loadMoreHistory() async {
        guard !isLoadingMore, hasMoreHistory, let oldest = messages.min(by: { $0.time < $1.time }) else { return }
        await MainActor.run { isLoadingMore = true }
        do {
            let older = try await client.getHistory(conversationId: conversationId, limit: pageSize, before: oldest.time)
            await MainActor.run {
                if older.isEmpty {
                    hasMoreHistory = false
                } else {
                    let merged = (older + messages)
                    let unique = Dictionary(grouping: merged, by: { $0.id })
                        .compactMap { $0.value.first }
                        .sorted { $0.time < $1.time }
                    messages = unique
                    hasMoreHistory = older.count == pageSize
                }
                isLoadingMore = false
            }
        } catch {
            await MainActor.run { isLoadingMore = false }
        }
    }

    /// 撤回消息
    private func retractMessage(_ messageId: String) {
        Task {
            do {
                await client.retractMessage(messageId: messageId, toAliasId: theirAliasId, conversationId: conversationId)

                // 从列表中移除或标记为已撤回
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == messageId }) {
                        messages.remove(at: index)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Chat Header

struct ChatHeaderBar: View {
    let nickname: String
    let aliasId: String
    let onClose: () -> Void
    let onAudioCall: () -> Void
    let onVideoCall: () -> Void

    var body: some View {
        HStack(spacing: Spacing12) {
            Button(action: onClose) {
                HStack(spacing: Spacing8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("返回")
                }
                .foregroundColor(TextMuted)
            }

            VStack(alignment: .leading, spacing: Spacing2) {
                Text(nickname)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(TextPrimary)
                Text("@\(aliasId)")
                    .font(.system(size: 12))
                    .foregroundColor(TextMuted)
            }

            Spacer()

            Button(action: onAudioCall) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16))
                    .foregroundColor(BlueAccent)
            }

            Button(action: onVideoCall) {
                Image(systemName: "video.fill")
                    .font(.system(size: 16))
                    .foregroundColor(BlueAccent)
            }
        }
        .padding(.horizontal, Spacing16)
        .padding(.vertical, Spacing12)
        .background(Surface1)
    }
}

// MARK: - Chat Input Bar
// 注：ChatInputBar 定义已迁至独立文件 ChatInputBar.swift

// MARK: - Security Verify Modal

struct SecurityVerifyModalView: View {
    @Binding var isPresented: Bool
    @State private var userInput = ""
    @State private var showError = false

    let expectedCode = "A1B2C3D4"  // 对方的安全码前 8 位

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
                    Text("你的安全码:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TextMuted)
                    Text("E5F6G7H8")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(TextPrimary)
                        .padding(Spacing8)
                        .background(Surface1)
                        .cornerRadius(RadiusSmall)
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
                        Text("安全码不匹配，请重新检查")
                            .foregroundColor(DangerColor)
                    }
                    .font(.system(size: 13))
                }

                HStack(spacing: Spacing12) {
                    Button(action: { isPresented = false }) {
                        Text("取消")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .secondaryButton()
                    .frame(height: Theme.buttonHeight)

                    Button(action: verifyCode) {
                        Text("核验")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .primaryButton()
                    .frame(height: Theme.buttonHeight)
                }

                Spacer()
            }
            .padding(Spacing20)
            .background(Surface1)
            .cornerRadius(RadiusLarge)
            .padding(Spacing20)
        }
    }

    private func verifyCode() {
        if userInput.uppercased() == expectedCode {
            isPresented = false
        } else {
            showError = true
        }
    }
}

/// 语音录制 Sheet — 显示录制 UI，支持取消/发送
private struct VoiceRecorderSheet: View {
    var recorder: VoiceRecorder
    let onCancel: () -> Void
    let onSend: (Data, Int) -> Void
    @State private var ticker: Timer? = nil
    @State private var elapsed: Int = 0

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 10, height: 10)
                Text("正在录音...").font(.system(size: 16, weight: .semibold)).foregroundColor(TextPrimary)
            }
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(BlueAccent)
            Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundColor(TextPrimary)
            Text("点击「发送」分享语音，或取消")
                .font(.system(size: 12)).foregroundColor(TextMuted)
            HStack(spacing: 20) {
                Button(action: onCancel) {
                    Text("取消").foregroundColor(TextMuted)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(Surface1).cornerRadius(RadiusMedium)
                }
                Button(action: {
                    recorder.stop(save: true)
                    if case .finished(let data, let ms) = recorder.state {
                        onSend(data, ms)
                    } else {
                        onCancel()
                    }
                }) {
                    Text("发送").foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(BlueAccent).cornerRadius(RadiusMedium)
                }
                .disabled(elapsed < 1)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DarkBg)
        .onAppear {
            _ = recorder.start()
            ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                elapsed = recorder.elapsedSeconds
            }
        }
        .onDisappear {
            ticker?.invalidate()
            ticker = nil
        }
    }
}

#Preview {
    ChatView(appState: AppState(), conversationId: "conv1")
}
