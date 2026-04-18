//
//  SettingsView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import UIKit
import LocalAuthentication
import SecureChatSDK
import UserNotifications

/// 设置屏幕
struct SettingsView: View {
    @State var appState: AppState
    @State private var showMnemonicModal = false
    @State private var mnemonicInput = ""
    @State private var showMnemonic = false
    @State private var showConfirmLogout = false
    @State private var notificationsEnabled = true
    @State private var exportShareItems: [Any]? = nil
    @State private var isExporting = false
    @State private var storage: StorageEstimate? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶栏
                HStack {
                    Text("设置")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(TextPrimary)
                    Spacer()
                }
                .padding(.horizontal, Spacing20)
                .padding(.vertical, Spacing16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing20) {
                        // 用户信息卡片
                        if let userInfo = appState.userInfo {
                            VStack(spacing: Spacing12) {
                                HStack(spacing: Spacing12) {
                                    ZStack {
                                        Circle()
                                            .fill(BlueAccent.opacity(0.2))
                                        Text(userInfo.nickname.prefix(2).uppercased())
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(BlueAccent)
                                    }
                                    .frame(width: 60, height: 60)

                                    VStack(alignment: .leading, spacing: Spacing4) {
                                        Text(userInfo.nickname)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(TextPrimary)
                                        HStack(spacing: Spacing8) {
                                            Text("@\(userInfo.aliasId)")
                                                .font(.system(size: 13))
                                                .foregroundColor(TextMuted)
                                            Button(action: {
                                                UIPasteboard.general.string = userInfo.aliasId
                                            }) {
                                                Image(systemName: "doc.on.doc")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(BlueAccent)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(Spacing16)
                                .background(Surface1)
                                .cornerRadius(RadiusMedium)
                            }
                            .padding(.horizontal, Spacing20)
                        }

                        // 加密信息卡
                        VStack(alignment: .leading, spacing: Spacing8) {
                            Text("加密")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(TextMuted)
                                .padding(.horizontal, Spacing20)

                            HStack(spacing: Spacing12) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(SuccessColor)
                                VStack(alignment: .leading, spacing: Spacing4) {
                                    Text("端对端加密")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(TextPrimary)
                                    Text("X25519-AES-GCM-256")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(TextMuted)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(SuccessColor)
                            }
                            .padding(Spacing16)
                            .background(Surface1)
                            .cornerRadius(RadiusMedium)
                            .padding(.horizontal, Spacing20)
                        }

                        // 快捷操作
                        VStack(alignment: .leading, spacing: Spacing8) {
                            Text("账户")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(TextMuted)
                                .padding(.horizontal, Spacing20)

                            VStack(spacing: 0) {
                                SettingRow(
                                    icon: "key.fill",
                                    title: "查看助记词",
                                    action: {
                                        showMnemonicModal = true
                                    }
                                )

                                Divider()
                                    .background(Surface2)
                                    .padding(.horizontal, Spacing20)

                                SettingRow(
                                    icon: "bell.fill",
                                    title: "推送通知",
                                    trailing: {
                                        Toggle("", isOn: $notificationsEnabled)
                                            .tint(BlueAccent)
                                            .onChange(of: notificationsEnabled) { _, newVal in
                                                if newVal {
                                                    Task {
                                                        let granted = await requestPushPermissionAndRegister()
                                                        if !granted {
                                                            await MainActor.run {
                                                                notificationsEnabled = false
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                    }
                                )

                                Divider()
                                    .background(Surface2)
                                    .padding(.horizontal, Spacing20)

                                SettingRow(
                                    icon: "square.and.arrow.up",
                                    title: isExporting ? "导出中…" : "导出聊天 (NDJSON)",
                                    action: { exportChats() }
                                )

                                Divider()
                                    .background(Surface2)
                                    .padding(.horizontal, Spacing20)

                                SettingRow(
                                    icon: "internaldrive",
                                    title: storage.map {
                                        let used = Double($0.usedBytes) / 1024.0 / 1024.0
                                        let quota = Double($0.quotaBytes) / 1024.0 / 1024.0
                                        return quota > 0
                                            ? String(format: "存储：%.1f MB / %.1f MB", used, quota)
                                            : String(format: "存储：%.1f MB", used)
                                    } ?? "存储：加载中…",
                                    action: {}
                                )

                                Divider()
                                    .background(Surface2)
                                    .padding(.horizontal, Spacing20)

                                SettingRow(
                                    icon: "info.circle.fill",
                                    title: "关于",
                                    action: {}
                                )
                            }
                            .background(Surface1)
                            .cornerRadius(RadiusMedium)
                            .padding(.horizontal, Spacing20)
                        }

                        // 危险区
                        VStack(alignment: .leading, spacing: Spacing8) {
                            Text("危险区")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DangerColor)
                                .padding(.horizontal, Spacing20)

                            Button(action: {
                                showConfirmLogout = true
                            }) {
                                HStack(spacing: Spacing12) {
                                    Image(systemName: "power")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(DangerColor)
                                    Text("退出并清除所有数据")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(DangerColor)
                                    Spacer()
                                }
                                .padding(Spacing16)
                                .background(DangerColor.opacity(0.1))
                                .cornerRadius(RadiusMedium)
                            }
                            .padding(.horizontal, Spacing20)
                        }

                        Text("v1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(TextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing20)
                    }
                    .padding(.vertical, Spacing20)
                }
                .background(DarkBg)
            }
            .background(DarkBg)
            .task {
                do {
                    let est = try await SecureChatClient.shared().getStorageEstimate()
                    await MainActor.run { storage = est }
                } catch {
                    // 忽略
                }
            }
            .sheet(isPresented: $showMnemonicModal) {
                MnemonicModalView(isPresented: $showMnemonicModal, showMnemonic: $showMnemonic)
            }
            .alert("退出", isPresented: $showConfirmLogout) {
                Button("取消", role: .cancel) {}
                Button("确认退出", role: .destructive) {
                    logoutAndClear()
                }
            } message: {
                Text("确认要退出并清除所有数据吗？此操作不可撤销。")
            }
            .sheet(isPresented: Binding(
                get: { exportShareItems != nil },
                set: { if !$0 { exportShareItems = nil } }
            )) {
                if let items = exportShareItems {
                    ShareSheet(activityItems: items)
                }
            }
        }
    }

    /// 导出全部聊天为 NDJSON 文件并通过系统分享 sheet 打开
    private func exportChats() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            defer { Task { @MainActor in isExporting = false } }
            do {
                let client = SecureChatClient()
                let ndjson = try await client.exportAllConversations()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let fileName = "securechat_export_\(formatter.string(from: Date())).ndjson"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try ndjson.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run {
                    exportShareItems = [url]
                }
            } catch {
                print("export failed: \(error)")
            }
        }
    }

    private func logoutAndClear() {
        Task {
            do {
                let client = SecureChatClient()

                // 调用 SDK 登出（清除本地数据和 token）
                try await client.logout()

                // 清空所有历史消息
                try await client.clearAllHistory()

                // 清除应用状态
                await MainActor.run {
                    appState.userInfo = nil
                    appState.sdkReady = false
                    appState.route = .welcome
                    appState.unreadCounts = [:]
                    appState.activeChatId = nil
                }
            } catch {
                print("登出错误: \(error.localizedDescription)")
                // 即使出错也清除本地状态
                await MainActor.run {
                    appState.userInfo = nil
                    appState.sdkReady = false
                    appState.route = .welcome
                    appState.unreadCounts = [:]
                    appState.activeChatId = nil
                }
            }
        }
    }
}

// MARK: - Setting Row Component

struct SettingRow<T: View>: View {
    let icon: String
    let title: String
    var trailing: (() -> T)? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: Spacing12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(BlueAccent)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(TextPrimary)

                Spacer()

                if let trailing = trailing {
                    trailing()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(TextMuted)
                }
            }
            .padding(Spacing16)
        }
    }
}

// 便利扩展：无 trailing 时直接构造 SettingRow，省去 T 推断
extension SettingRow where T == EmptyView {
    init(
        icon: String,
        title: String,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.trailing = nil
        self.action = action
    }
}

// MARK: - Mnemonic Modal

struct MnemonicModalView: View {
    @Binding var isPresented: Bool
    @Binding var showMnemonic: Bool
    @State private var mnemonic: String = ""
    @State private var authError: String? = nil
    @State private var isAuthenticating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing20) {
                HStack {
                    Text("查看助记词")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TextPrimary)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(TextMuted)
                    }
                }
                .padding(.horizontal, Spacing20)
                .padding(.top, Spacing20)

                if !showMnemonic {
                    VStack(spacing: Spacing20) {
                        Text("助记词是账号唯一凭证。在私密环境下查看，永不分享。")
                            .font(.system(size: 15))
                            .foregroundColor(TextMuted)
                            .lineSpacing(1.5)
                            .multilineTextAlignment(.center)

                        if let err = authError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(DangerColor)
                        }

                        Button(action: { Task { await authenticateAndLoadMnemonic() } }) {
                            HStack(spacing: 8) {
                                if isAuthenticating {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "faceid")
                                }
                                Text(isAuthenticating ? "验证中…" : "Face ID / Touch ID 验证")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .primaryButton()
                        .frame(height: Theme.buttonHeight)
                        .disabled(isAuthenticating)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing20)
                    .padding(.vertical, Spacing20)
                } else {
                    VStack(alignment: .leading, spacing: Spacing12) {
                        VStack(alignment: .leading, spacing: Spacing4) {
                            Text("⚠️ 安全警告")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DangerColor)
                            Text("永远不要向任何人分享这些单词")
                                .font(.system(size: 12))
                                .foregroundColor(TextMuted)
                        }

                        Text(mnemonic)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundColor(TextPrimary)
                            .padding(Spacing12)
                            .background(Surface1)
                            .cornerRadius(RadiusMedium)
                            .textSelection(.enabled)

                        Button(action: {
                            // iOS 10+ setItems options: 60 秒后自动过期 + localOnly
                            // localOnly=true 阻止通过 Handoff 同步到其它 Apple 设备
                            let item: [String: Any] = [UIPasteboard.typeAutomatic: mnemonic]
                            UIPasteboard.general.setItems([item], options: [
                                .expirationDate: Date().addingTimeInterval(60),
                                .localOnly: true,
                            ])
                        }) {
                            HStack(spacing: Spacing8) {
                                Image(systemName: "doc.on.doc")
                                Text("复制 (60 秒后清空)")
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                        .secondaryButton()
                        .frame(height: Theme.inputHeight)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing20)
                    .padding(.vertical, Spacing20)
                }
            }
            .background(DarkBg)
        }
    }

    /// 生物识别验证（Face ID / Touch ID），通过后从 SDK 加载真实助记词
    private func authenticateAndLoadMnemonic() async {
        await MainActor.run { isAuthenticating = true; authError = nil }
        defer { Task { @MainActor in isAuthenticating = false } }

        let context = LAContext()
        context.localizedCancelTitle = "取消"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            await MainActor.run { authError = "设备不支持生物识别：\(error?.localizedDescription ?? "")" }
            return
        }

        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "查看恢复助记词需要验证身份"
            )
            if !ok {
                await MainActor.run { authError = "验证被取消" }
                return
            }
        } catch {
            await MainActor.run { authError = "验证失败：\(error.localizedDescription)" }
            return
        }

        // 验证通过 — 从 SDK 加载真实助记词
        do {
            let m = try await SecureChatClient.shared().getMnemonic() ?? ""
            await MainActor.run {
                mnemonic = m.isEmpty ? "未找到助记词（账号可能未初始化）" : m
                showMnemonic = true
            }
        } catch {
            await MainActor.run {
                authError = "加载助记词失败：\(error.localizedDescription)"
            }
        }
    }
}

/// SwiftUI 桥接 UIActivityViewController 实现系统分享 sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView(appState: AppState())
}
