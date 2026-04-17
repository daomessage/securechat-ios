//
//  MainView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import SecureChatSDK

/// 主界面 — TabView 包含 4 个 Tab（消息、频道、联系人、设置）
struct MainView: View {
    @State var appState: AppState
    @State private var showPushPrompt: Bool = !UserDefaults.standard.bool(forKey: "push_prompted")

    var body: some View {
        ZStack {
            TabView(selection: $appState.activeTab) {
                // 消息 Tab
                MessagesTab(appState: appState)
                    .tabItem {
                        Label("消息", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(MainTab.messages)
                    .badge(appState.totalUnread)

                // 频道 Tab
                ChannelsTab(appState: appState)
                    .tabItem {
                        Label("频道", systemImage: "megaphone")
                    }
                    .tag(MainTab.channels)

                // 联系人 Tab
                ContactsTab(appState: appState)
                    .tabItem {
                        Label("联系人", systemImage: "person.2")
                    }
                    .tag(MainTab.contacts)
                    .badge(appState.pendingFriendRequestCount)

                // 设置 Tab
                SettingsView(appState: appState)
                    .tabItem {
                        Label("设置", systemImage: "gear")
                    }
                    .tag(MainTab.settings)
            }
            .background(DarkBg)

            // 当打开聊天时，显示聊天界面覆盖
            if let chatId = appState.activeChatId {
                ChatView(appState: appState, conversationId: chatId)
            }
        }
        .alert("开启通知", isPresented: $showPushPrompt) {
            Button("稍后") {
                UserDefaults.standard.set(true, forKey: "push_prompted")
            }
            Button("启用") {
                UserDefaults.standard.set(true, forKey: "push_prompted")
                Task { _ = await requestPushPermissionAndRegister() }
            }
        } message: {
            Text("开启通知以便及时收到好友消息。")
        }
    }
}

// MARK: - Messages Tab

struct MessagesTab: View {
    @State var appState: AppState
    @State private var sessions: [SessionEntity] = []
    @State private var isLoading = true
    @State private var lastMessageMap: [String: String] = [:]
    @State private var showDeleteConfirm = false
    @State private var deleteConvId: String? = nil

    private let client = SecureChatClient.shared()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶栏
                HStack {
                    Text("消息")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(TextPrimary)
                    Spacer()
                }
                .padding(.horizontal, Spacing20)
                .padding(.vertical, Spacing16)

                if isLoading {
                    VStack {
                        ProgressView()
                            .tint(BlueAccent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DarkBg)
                } else if sessions.isEmpty {
                    VStack(spacing: Spacing8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(TextMuted)
                        Text("暂无会话")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(TextMuted)
                        Text("添加好友开始聊天")
                            .font(.system(size: 13))
                            .foregroundColor(TextMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DarkBg)
                } else {
                    List {
                        ForEach(sessions, id: \.conversationId) { session in
                            ConversationSessionRow(
                                session: session,
                                lastMessage: lastMessageMap[session.conversationId] ?? "",
                                unread: appState.unreadCounts[session.conversationId] ?? 0,
                                onTap: {
                                    appState.activeChatId = session.conversationId
                                    appState.clearUnread(session.conversationId)
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteConvId = session.conversationId
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .background(DarkBg)
                        }
                    }
                    .listStyle(.plain)
                    .background(DarkBg)
                    .alert("Delete Chat", isPresented: $showDeleteConfirm) {
                        Button("Cancel", role: .cancel) { deleteConvId = nil }
                        Button("Delete", role: .destructive) {
                            if let convId = deleteConvId {
                                Task {
                                    try? await client.clearHistory(conversationId: convId)
                                    await MainActor.run {
                                        appState.clearUnread(convId)
                                        lastMessageMap[convId] = nil
                                    }
                                }
                            }
                            deleteConvId = nil
                        }
                    } message: {
                        Text("Delete all messages in this conversation? This cannot be undone.")
                    }
                }
            }
            .background(DarkBg)
            .task {
                await loadSessions()
            }
        }
    }

    private func loadSessions() async {
        do {
            let allSessions = try await client.listSessions()
            await MainActor.run {
                sessions = allSessions
            }

            // 加载每个会话的最后一条消息
            for session in allSessions {
                do {
                    let history = try await client.getHistory(conversationId: session.conversationId, limit: 1, before: nil)
                    if let lastMsg = history.first {
                        await MainActor.run {
                            lastMessageMap[session.conversationId] = lastMsg.text
                        }
                    }
                } catch {
                    // 忽略加载失败
                }
            }

            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("加载会话失败: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ConversationSessionRow: View {
    let session: SessionEntity
    let lastMessage: String
    let unread: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing14) {
                // 头像
                ZStack {
                    Circle()
                        .fill(BlueAccent.opacity(0.2))

                    Text(session.theirAliasId.prefix(2).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(BlueAccent)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: Spacing4) {
                    HStack {
                        Text(session.theirAliasId)
                            .font(.system(size: 15, weight: unread > 0 ? .bold : .regular))
                            .foregroundColor(TextPrimary)
                        Spacer()
                        Text(formatTime(session.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(TextMuted)
                    }

                    Text(lastMessage.isEmpty ? "[暂无消息]" : lastMessage)
                        .font(.system(size: 13))
                        .foregroundColor(TextMuted)
                        .lineLimit(1)
                }

                if unread > 0 {
                    ZStack {
                        Circle()
                            .fill(BlueAccent)
                        Text("\(min(unread, 99))\(unread > 99 ? "+" : "")")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(TextPrimary)
                    }
                    .frame(width: 20, height: 20)
                }

                Text("🔒")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, Spacing20)
            .padding(.vertical, Spacing12)
            .contentShape(Rectangle())
        }
    }

    private func formatTime(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let elapsed = Date().timeIntervalSince(date)
        if elapsed < 60 { return "刚刚" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))分钟" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))小时" }
        return "昨天"
    }
}

// SessionEntity 直接使用 SecureChatSDK.SessionEntity（已有 conversationId/theirAliasId 等字段）

// MARK: - Channels Tab

struct ChannelsTab: View {
    @State var appState: AppState
    @State private var channels: [ChannelInfo] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var newChannelName = ""
    @State private var newChannelDesc = ""
    @State private var quotaOrder: ChannelTradeOrder? = nil
    @State private var showQuotaPay = false
    @State private var creationError: String? = nil

    private let client = SecureChatClient.shared()

    var body: some View {
        VStack(spacing: Spacing16) {
            HStack {
                Text("频道")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(TextPrimary)
                Spacer()
                Button(action: { showCreate = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(BlueAccent)
                }
            }
            .padding(.horizontal, Spacing20)
            .padding(.top, Spacing16)

            if isLoading {
                VStack {
                    ProgressView()
                        .tint(BlueAccent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if channels.isEmpty {
                VStack(spacing: Spacing8) {
                    Image(systemName: "megaphone")
                        .font(.system(size: 40))
                        .foregroundColor(TextMuted)
                    Text("暂无频道")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(TextMuted)
                    Text("加入或创建频道来参与讨论")
                        .font(.system(size: 13))
                        .foregroundColor(TextMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(channels, id: \.id) { channel in
                        VStack(alignment: .leading, spacing: Spacing8) {
                            Text(channel.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(TextPrimary)
                            Text(channel.description)
                                .font(.system(size: 13))
                                .foregroundColor(TextMuted)
                                .lineLimit(2)
                        }
                        .padding(.vertical, Spacing8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 打开频道详情
                        }
                    }
                }
                .listStyle(.plain)
                .background(DarkBg)
            }

            Spacer()
        }
        .background(DarkBg)
        .task {
            await loadChannels()
        }
        .alert("创建频道", isPresented: $showCreate) {
            TextField("名称", text: $newChannelName)
            TextField("描述", text: $newChannelDesc)
            Button("取消", role: .cancel) {
                newChannelName = ""; newChannelDesc = ""
            }
            Button("创建") {
                Task { await createChannel() }
            }
        }
        .alert("配额已用尽", isPresented: $showQuotaPay) {
            Button("取消", role: .cancel) { quotaOrder = nil }
            Button("我已支付，重试") {
                Task {
                    showQuotaPay = false
                    await retryCreate()
                }
            }
        } message: {
            if let order = quotaOrder {
                Text("需要支付 \(Int(order.priceUsdt)) USDT 至 \(order.payTo) 以扩充配额。")
            }
        }
        .alert("创建失败", isPresented: Binding(
            get: { creationError != nil },
            set: { if !$0 { creationError = nil } }
        )) {
            Button("确定", role: .cancel) { creationError = nil }
        } message: {
            Text(creationError ?? "")
        }
    }

    private func createChannel() async {
        let name = newChannelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = newChannelDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            _ = try await client.channels?.create(name: name, description: desc)
            await loadChannels()
            await MainActor.run {
                newChannelName = ""; newChannelDesc = ""
            }
        } catch {
            let msg = error.localizedDescription
            if msg.uppercased().contains("QUOTA") {
                // 触发买配额流程
                if let order = try? await client.channels?.buyQuota() {
                    await MainActor.run {
                        quotaOrder = order
                        showQuotaPay = true
                    }
                } else {
                    await MainActor.run { creationError = "无法发起配额支付" }
                }
            } else {
                await MainActor.run { creationError = msg }
            }
        }
    }

    private func retryCreate() async {
        await createChannel()
    }

    private func loadChannels() async {
        do {
            let myChannels = try await client.channels?.getMine() ?? []
            await MainActor.run {
                channels = myChannels
                isLoading = false
            }
        } catch {
            print("加载频道失败: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Contacts Tab

struct ContactsTab: View {
    @State var appState: AppState
    @State private var searchText = ""
    @State private var showQRScanner = false
    @State private var showMyQR = false
    @State private var friends: [FriendProfile] = []
    @State private var searchResult: UserProfile? = nil
    @State private var isSearching = false
    @State private var isLoading = true
    @State private var toastMessage: String? = nil

    private let client = SecureChatClient.shared()

    var acceptedFriends: [FriendProfile] {
        friends.filter { $0.status == .accepted }
    }

    var pendingReceived: [FriendProfile] {
        friends.filter { $0.status == .pending && $0.direction == "received" }
    }

    var pendingSent: [FriendProfile] {
        friends.filter { $0.status == .pending && $0.direction == "sent" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("联系人")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(TextPrimary)
                    if !pendingReceived.isEmpty {
                        Text("\(pendingReceived.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(TextPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BlueAccent)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button(action: { showQRScanner = true }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(BlueAccent)
                    }
                    Button(action: { showMyQR = true }) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 20))
                            .foregroundColor(BlueAccent)
                    }
                }
                .padding(.horizontal, Spacing20)
                .padding(.vertical, Spacing16)

                // 搜索框
                HStack(spacing: Spacing8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(TextMuted)
                    TextField("按 alias ID 搜索并添加", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(TextPrimary)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, newVal in
                            if newVal.count >= 2 {
                                searchUser(newVal)
                            } else {
                                searchResult = nil
                            }
                        }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; searchResult = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(TextMuted)
                        }
                    }
                }
                .frame(height: Theme.inputHeight)
                .padding(.horizontal, Spacing12)
                .background(Surface1)
                .cornerRadius(RadiusMedium)
                .padding(.horizontal, Spacing20)
                .padding(.bottom, Spacing12)

                // 搜索结果卡片（带 Add 按钮）
                if let user = searchResult {
                    HStack(spacing: Spacing12) {
                        ZStack {
                            Circle().fill(BlueAccent.opacity(0.2))
                            Text(user.nickname.prefix(2).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(BlueAccent)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.nickname)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(TextPrimary)
                            Text("@\(user.aliasId)")
                                .font(.system(size: 12))
                                .foregroundColor(TextMuted)
                        }
                        Spacer()
                        Button("加好友") {
                            sendRequest(user.aliasId)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(BlueAccent)
                        .foregroundColor(TextPrimary)
                        .cornerRadius(RadiusSmall)
                    }
                    .padding(.horizontal, Spacing20).padding(.vertical, Spacing8)
                    .background(Surface1)
                    .cornerRadius(RadiusMedium)
                    .padding(.horizontal, Spacing20)
                    .padding(.bottom, Spacing12)
                }

                if isLoading {
                    VStack {
                        ProgressView().tint(BlueAccent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: Spacing8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundColor(TextMuted)
                        Text("暂无联系人")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(TextMuted)
                        Text("搜索或扫码添加好友")
                            .font(.system(size: 13))
                            .foregroundColor(TextMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // ── 待处理请求（收到）
                        if !pendingReceived.isEmpty {
                            Section(header: Text("待处理 (\(pendingReceived.count))").foregroundColor(TextMuted)) {
                                ForEach(pendingReceived, id: \.friendshipId) { req in
                                    PendingRequestRow(
                                        friend: req,
                                        onAccept: { acceptRequest(req.friendshipId) },
                                        onReject: { rejectRequest(req.friendshipId) }
                                    )
                                }
                            }
                        }
                        // ── 已发送
                        if !pendingSent.isEmpty {
                            Section(header: Text("已发送 (\(pendingSent.count))").foregroundColor(TextMuted)) {
                                ForEach(pendingSent, id: \.friendshipId) { req in
                                    PendingRequestRow(friend: req, onAccept: nil, onReject: nil)
                                }
                            }
                        }
                        // ── 好友
                        if !acceptedFriends.isEmpty {
                            Section(header: Text("好友 (\(acceptedFriends.count))").foregroundColor(TextMuted)) {
                                ForEach(acceptedFriends, id: \.aliasId) { friend in
                                    HStack(spacing: Spacing12) {
                                        ZStack {
                                            Circle().fill(BlueAccent.opacity(0.2))
                                            Text(friend.nickname.prefix(2).uppercased())
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(BlueAccent)
                                        }
                                        .frame(width: 40, height: 40)

                                        VStack(alignment: .leading, spacing: Spacing4) {
                                            Text(friend.nickname)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(TextPrimary)
                                            Text("@\(friend.aliasId)")
                                                .font(.system(size: 12))
                                                .foregroundColor(TextMuted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, Spacing8)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        appState.activeChatId = friend.conversationId
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(DarkBg)
                }

                Spacer()
            }
            .background(DarkBg)
            .overlay(alignment: .top) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(TextPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(BlueAccent.opacity(0.9))
                        .cornerRadius(8)
                        .padding(.top, 60)
                }
            }
            .task {
                await loadFriends()
            }
            .sheet(isPresented: $showMyQR) {
                MyQRCodeView(
                    isPresented: $showMyQR,
                    aliasId: appState.userInfo?.aliasId ?? ""
                )
            }
            .fullScreenCover(isPresented: $showQRScanner) {
                QRScannerView(isPresented: $showQRScanner) { text in
                    if let alias = parseAliasFromQR(text) {
                        searchText = alias
                        searchUser(alias)
                    } else {
                        showToast("无效的二维码")
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func loadFriends() async {
        do {
            let allFriends = try await client.contacts?.syncFriends() ?? []
            await MainActor.run {
                friends = allFriends
                appState.pendingFriendRequestCount = allFriends.filter { $0.status == .pending && $0.direction == "received" }.count
                isLoading = false
            }
        } catch {
            print("加载好友列表失败: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func searchUser(_ aliasId: String) {
        Task {
            do {
                let user = try await client.contacts?.lookupUser(aliasId: aliasId)
                await MainActor.run {
                    searchResult = user
                }
            } catch {
                await MainActor.run {
                    searchResult = nil
                }
            }
        }
    }

    private func sendRequest(_ aliasId: String) {
        Task {
            do {
                try await client.contacts?.sendFriendRequest(toAliasId: aliasId)
                await MainActor.run {
                    showToast("好友请求已发送")
                    searchText = ""
                    searchResult = nil
                }
                await loadFriends()
            } catch {
                await MainActor.run {
                    showToast("发送失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func acceptRequest(_ friendshipId: Int) {
        Task {
            do {
                try await client.contacts?.acceptFriendRequest(friendshipId: friendshipId)
                await MainActor.run {
                    showToast("已添加为好友")
                }
                await loadFriends()
            } catch {
                await MainActor.run {
                    showToast("接受失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func rejectRequest(_ friendshipId: Int) {
        Task {
            do {
                try await client.contacts?.rejectFriendRequest(friendshipId: friendshipId)
                await MainActor.run { showToast("已拒绝") }
                await loadFriends()
            } catch {
                await MainActor.run { showToast("拒绝失败：\(error.localizedDescription)") }
            }
        }
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { toastMessage = nil }
        }
    }
}

private struct PendingRequestRow: View {
    let friend: FriendProfile
    let onAccept: (() -> Void)?
    let onReject: (() -> Void)?

    init(friend: FriendProfile, onAccept: (() -> Void)? = nil, onReject: (() -> Void)? = nil) {
        self.friend = friend
        self.onAccept = onAccept
        self.onReject = onReject
    }

    var body: some View {
        HStack(spacing: Spacing12) {
            ZStack {
                Circle().fill(BlueAccent.opacity(0.2))
                Text(friend.nickname.prefix(2).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(BlueAccent)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.nickname.isEmpty ? friend.aliasId : friend.nickname)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(TextPrimary)
                Text("@\(friend.aliasId)")
                    .font(.system(size: 12))
                    .foregroundColor(TextMuted)
            }
            Spacer()
            if let onAccept = onAccept {
                HStack(spacing: 6) {
                    if let onReject = onReject {
                        Button("拒绝", action: onReject)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Surface1)
                            .foregroundColor(TextMuted)
                            .cornerRadius(RadiusSmall)
                            .font(.system(size: 13))
                    }
                    Button("接受", action: onAccept)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(BlueAccent)
                        .foregroundColor(TextPrimary)
                        .cornerRadius(RadiusSmall)
                        .font(.system(size: 13, weight: .semibold))
                }
            } else {
                Text("待回应")
                    .font(.system(size: 12))
                    .foregroundColor(TextMuted)
            }
        }
        .padding(.vertical, Spacing4)
    }
}

#Preview {
    MainView(appState: AppState())
}
