//
//  AppState.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import Foundation
import Observation

/// 路由枚举 — 控制应用的主要屏幕导航
enum AppRoute: Hashable {
    case welcome
    case generateMnemonic
    case confirmBackup
    case vanityShop
    case setNickname
    case recover
    case main
}

/// 主界面 Tab 枚举
enum MainTab: Hashable {
    case messages
    case channels
    case contacts
    case settings
}

/// 用户信息数据模型
struct UserInfo: Identifiable {
    var id: String { aliasId }
    let aliasId: String
    let nickname: String
}

/// 网络连接状态（App 层自己的枚举，扩展了 SDK 的 NetworkState 增加 .kicked）
enum NetworkState: Equatable {
    case connected
    case disconnected(retryCount: Int)
    case connecting
    /// GOAWAY：被其他设备登录挤下线
    case kicked(reason: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// 通话状态
enum CallState: Equatable {
    case idle
    case ringing(from: String)
    case ongoing(duration: TimeInterval)
}

/// 全局应用状态管理器（iOS 17+ @Observable）
@Observable
final class AppState {
    var route: AppRoute = .welcome
    var sdkReady = false
    var userInfo: UserInfo? = nil
    var activeTab: MainTab = .messages
    var activeChatId: String? = nil
    var unreadCounts: [String: Int] = [:]
    var networkState: NetworkState = .disconnected(retryCount: 0)
    var callState: CallState? = nil
    var callRemoteAlias: String? = nil
    var pendingFriendRequestCount: Int = 0
    var showGoaway: Bool = false
    var goawayReason: String = ""

    /// 计算总未读数
    var totalUnread: Int { unreadCounts.values.reduce(0, +) }

    /// 清除指定会话的未读计数
    func clearUnread(_ convId: String) {
        unreadCounts[convId] = nil
    }

    /// 增加指定会话的未读计数
    func incrementUnread(_ convId: String) {
        unreadCounts[convId] = (unreadCounts[convId] ?? 0) + 1
    }
}
