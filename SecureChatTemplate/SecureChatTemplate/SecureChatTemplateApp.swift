//
//  SecureChatTemplateApp.swift
//  SecureChatTemplate
//
//  Created by leo on 2026/4/15.
//

import SwiftUI
import UIKit
import UserNotifications
import SecureChatSDK

@main
struct SecureChatTemplateApp: App {
    @State private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            NavigationView(appState: appState)
                .task {
                    await initializeApp()
                }
        }
    }

    // MARK: - App Initialization

    /// 初始化应用 - 尝试恢复会话或显示欢迎屏幕
    private func initializeApp() async {
        let client = SecureChatClient.shared()

        do {
            // 尝试恢复历史会话
            if let (aliasId, nickname) = try await client.auth?.restoreSession() {
                // 会话恢复成功
                await MainActor.run {
                    appState.userInfo = UserInfo(aliasId: aliasId, nickname: nickname)
                }

                // 建立 WebSocket 连接
                await client.connect()

                // 设置 SDK 事件监听器
                await setupSDKListeners(client)

                // 更新状态
                await MainActor.run {
                    appState.sdkReady = true
                    appState.route = .main
                }
            } else {
                // 没有历史会话，显示欢迎屏幕
                await MainActor.run {
                    appState.route = .welcome
                }
            }
        } catch {
            // 恢复失败，显示欢迎屏幕
            print("会话恢复失败: \(error.localizedDescription)")
            await MainActor.run {
                appState.route = .welcome
            }
        }
    }

    /// 设置 SDK 事件监听器
    private func setupSDKListeners(_ client: SecureChatClient) async {
        // 监听新消息
        _ = await client.onMessage { [appState] msg in
            Task { @MainActor in
                // 如果消息来自不是当前活跃聊天的会话，增加未读计数
                if !msg.isMe && appState.activeChatId != msg.conversationId {
                    appState.incrementUnread(msg.conversationId)
                }
            }
        }

        // 监听网络状态变化（App 层的 NetworkState 独立于 SDK 的 NetworkState，
        // 通过 client.onNetworkStateChange 获取的是 SDK 版本，这里暂不桥接——
        // 留待 App 层后续订阅 transport 或自建状态机）

        // 监听输入状态
        _ = await client.onTyping { _ in
            // 在具体聊天视图处理输入状态
        }
    }
}

/// AppDelegate — 处理 APNS 注册回调
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// 取到 APNS device token → 上报 SDK
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenStr = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            do {
                try await SecureChatClient.shared().push?.registerAPNsToken(tokenStr)
            } catch {
                print("Push register failed: \(error)")
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNS register failed: \(error)")
    }

    /// 前台收到通知时仍然展示
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    /// 通知点击 → 取出 conv_id 走 deeplink
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let convId = userInfo["conv_id"] as? String {
            NotificationCenter.default.post(name: .openConversation, object: convId)
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let openConversation = Notification.Name("SecureChatOpenConversation")
}

/// 顶层工具：从 SettingsView 等处请求权限并触发 APNS 注册
@MainActor
func requestPushPermissionAndRegister() async -> Bool {
    do {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    } catch {
        return false
    }
}
