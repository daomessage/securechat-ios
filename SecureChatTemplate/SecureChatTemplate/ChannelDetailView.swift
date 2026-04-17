//
//  ChannelDetailView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import SecureChatSDK

/// 频道详情页面
/// - 频道名称 + 描述
/// - 帖子列表（分页加载）
/// - 发帖输入框（纯文本）
/// - 发帖调用 SDK channels.postMessage
struct ChannelDetailView: View {
    @State var appState: AppState
    let channelId: String
    let channelName: String

    @State private var posts: [ChannelPost] = []
    @State private var postText = ""
    @State private var isLoading = true
    @State private var isPosting = false
    @State private var errorMessage: String? = nil
    @State private var isSubscribed: Bool = false
    @State private var channelInfo: ChannelInfo? = nil

    private let client = SecureChatClient.shared()

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack {
                VStack(alignment: .leading, spacing: Spacing4) {
                    Text(channelName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TextPrimary)
                    Text(isSubscribed ? "已订阅" : "频道")
                        .font(.system(size: 12))
                        .foregroundColor(TextMuted)
                }

                Spacer()

                // For-sale 购买
                if channelInfo?.role != "owner" && channelInfo?.forSale == true {
                    Button(action: {
                        Task { await buyThisChannel() }
                    }) {
                        Text("Buy \(Int(channelInfo?.salePrice ?? 0)) USDT")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(RadiusSmall)
                    }
                }
                // 订阅/退订 — 非 owner 可见
                if channelInfo?.role != "owner" && channelInfo?.role != "admin" {
                    Button(action: {
                        Task { await toggleSubscribe() }
                    }) {
                        Text(isSubscribed ? "退订" : "订阅")
                            .font(.system(size: 13))
                            .foregroundColor(isSubscribed ? TextMuted : .white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(isSubscribed ? Surface2 : BlueAccent)
                            .cornerRadius(RadiusSmall)
                    }
                }
            }
            .padding(.horizontal, Spacing16)
            .padding(.vertical, Spacing12)
            .background(Surface1)

            // 帖子列表
            if isLoading {
                VStack {
                    ProgressView()
                        .tint(BlueAccent)
                }
                .frame(maxHeight: .infinity)
            } else if posts.isEmpty {
                VStack(spacing: Spacing8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(TextMuted)
                    Text("暂无帖子")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(TextMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing12) {
                        ForEach(posts, id: \.id) { post in
                            VStack(alignment: .leading, spacing: Spacing8) {
                                HStack(spacing: Spacing8) {
                                    ZStack {
                                        Circle()
                                            .fill(BlueAccent.opacity(0.2))
                                        Text(post.authorAliasId.prefix(2).uppercased())
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(BlueAccent)
                                    }
                                    .frame(width: 32, height: 32)

                                    VStack(alignment: .leading, spacing: Spacing2) {
                                        Text(post.authorAliasId)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(TextPrimary)
                                        Text(formatDate(post.createdAt))
                                            .font(.system(size: 11))
                                            .foregroundColor(TextMuted)
                                    }

                                    Spacer()
                                }

                                postContentView(for: post)
                                    .font(.system(size: 14))
                                    .foregroundColor(TextPrimary)
                                    .lineSpacing(1.5)
                                    .textSelection(.enabled)
                            }
                            .padding(Spacing12)
                            .background(Surface1)
                            .cornerRadius(RadiusMedium)
                        }
                    }
                    .padding(Spacing12)
                }
            }

            // 发帖输入框
            VStack(spacing: Spacing8) {
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(DangerColor)
                        .padding(Spacing8)
                        .background(DangerColor.opacity(0.1))
                        .cornerRadius(RadiusSmall)
                        .padding(.horizontal, Spacing12)
                }

                HStack(spacing: Spacing8) {
                    VStack {
                        TextEditor(text: $postText)
                            .font(.system(size: 14))
                            .foregroundColor(TextPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Spacing8)
                            .frame(minHeight: 40, maxHeight: 80)
                    }
                    .background(Surface1)
                    .cornerRadius(RadiusMedium)

                    Button(action: postToChannel) {
                        if isPosting {
                            ProgressView()
                                .tint(BlueAccent)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16))
                                .foregroundColor(postText.trimmingCharacters(in: .whitespaces).isEmpty ? TextMuted : BlueAccent)
                        }
                    }
                    .disabled(postText.trimmingCharacters(in: .whitespaces).isEmpty || isPosting)
                }
                .padding(Spacing12)
            }
            .background(DarkBg)
        }
        .background(DarkBg)
        .task {
            await loadPosts()
        }
    }

    private func loadPosts() async {
        do {
            async let detailTask: ChannelInfo? = {
                try? await client.channels?.getDetail(channelId: channelId)
            }()
            async let postsTask = client.channels?.getPosts(channelId: channelId) ?? []
            let (detail, channelPosts) = await (detailTask, postsTask)
            await MainActor.run {
                channelInfo = detail
                isSubscribed = detail?.isSubscribed ?? false
                posts = channelPosts
                isLoading = false
            }
        } catch {
            print("加载帖子失败: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func buyThisChannel() async {
        do {
            let order = try await client.channels?.buyChannel(channelId: channelId)
            if let o = order {
                await MainActor.run {
                    errorMessage = "订单 \(o.orderId)：\(o.priceUsdt) USDT → \(o.payTo)"
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func toggleSubscribe() async {
        do {
            if isSubscribed {
                try await client.channels?.unsubscribe(channelId: channelId)
                await MainActor.run { isSubscribed = false }
            } else {
                try await client.channels?.subscribe(channelId: channelId)
                await MainActor.run { isSubscribed = true }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func postToChannel() {
        guard !postText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let content = postText
        isPosting = true
        errorMessage = nil

        Task {
            do {
                // 发布帖子
                let _ = try await client.channels?.postMessage(
                    channelId: channelId,
                    content: content,
                    type: "text"
                )

                // 重新加载帖子
                await loadPosts()

                // 清空输入框
                await MainActor.run {
                    postText = ""
                    isPosting = false
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// 渲染帖子内容：type=="markdown" 用 AttributedString，否则纯文本
    @ViewBuilder
    private func postContentView(for post: ChannelPost) -> some View {
        if post.type == "markdown" {
            if let attr = try? AttributedString(
                markdown: post.content,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
            ) {
                Text(attr)
            } else {
                Text(post.content)
            }
        } else {
            Text(post.content)
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterFallback: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    private func formatDate(_ dateStr: String) -> String {
        let date = Self.isoFormatter.date(from: dateStr)
            ?? Self.isoFormatterFallback.date(from: dateStr)
        guard let d = date else { return dateStr }
        let elapsed = Date().timeIntervalSince(d)
        if elapsed < 60 { return "刚刚" }
        if elapsed < 3600 { return "\(Int(elapsed / 60)) 分钟前" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600)) 小时前" }
        if elapsed < 604800 { return "\(Int(elapsed / 86400)) 天前" }
        return Self.displayFormatter.string(from: d)
    }
}

#Preview {
    ChannelDetailView(
        appState: AppState(),
        channelId: "ch1",
        channelName: "General"
    )
}
