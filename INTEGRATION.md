# iOS App — SDK 集成指南

本文档说明如何将 DAO MESSAGE SDK 集成到 iOS 应用中。

## 前置条件

- Xcode 15.0 或更高版本
- iOS 16+ 作为最低部署目标
- Swift 5.9 或更高版本
- SDK 已位于 `../sdk-ios`（相对路径）

## 步骤 1: 项目结构

当前项目结构：

```
chat/
├── sdk-ios/                          ← SDK 源码（本地 Swift Package）
│   ├── Package.swift
│   ├── Sources/
│   │   └── SecureChatSDK/
│   │       ├── Client.swift
│   │       ├── Auth.swift
│   │       ├── Messaging.swift
│   │       ├── Contacts.swift
│   │       └── ...
│   └── Tests/
│
└── template-app-ios/
    └── SecureChatTemplate/
        ├── SecureChatTemplate.xcodeproj
        └── SecureChatTemplate/
            ├── SecureChatTemplateApp.swift
            ├── AppState.swift
            ├── Navigation.swift
            ├── Theme.swift
            ├── Helpers.swift
            ├── WelcomeView.swift
            ├── GenerateMnemonicView.swift
            ├── ... (其他 View 文件)
            └── SettingsView.swift
```

## 步骤 2: 在 Xcode 中添加 SDK 包

### 方法 A: 使用 Xcode UI（推荐）

1. 打开 `template-app-ios/SecureChatTemplate/SecureChatTemplate.xcodeproj`
2. 在 Xcode 菜单中：**File → Add Packages**
3. 在弹出窗口中，选择左下角的 **Add Local**
4. 导航到 `chat/sdk-ios` 目录，点击 **Open**
5. 选择 **SecureChatTemplate** target，点击 **Add Package**

### 方法 B: 手动编辑 project.pbxproj

如果 Xcode UI 方法不起作用，可手动编辑 `project.pbxproj`：

1. 右键点击 `SecureChatTemplate.xcodeproj`，选择 **Show in Finder**
2. 右键点击 `project.pbxproj`，选择 **Open With → TextEdit**（或任何文本编辑器）
3. 查找 `/* Build Phases */` 部分
4. 在 `Link Binary With Libraries` 中添加：
   ```
   "SecureChatSDK" => { package = "sdk-ios"; };
   ```

## 步骤 3: SDK 初始化

在 `SecureChatTemplateApp.swift` 中，SDK 初始化流程如下：

```swift
import SwiftUI
import SecureChatSDK  // ← 导入 SDK

@main
struct SecureChatTemplateApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            NavigationView(appState: appState)
                .task {
                    await setupSDKListeners()
                }
        }
    }

    private func setupSDKListeners() async {
        let client = SecureChatClient.shared

        // 1. 设置消息事件监听
        client.onMessage = { [weak self] msg in
            DispatchQueue.main.async {
                // 如果当前不在这个会话中，增加未读计数
                if self?.appState.activeChatId != msg.conversationId {
                    self?.appState.incrementUnread(msg.conversationId)
                }
            }
        }

        // 2. 设置网络状态监听
        client.onNetworkState = { [weak self] state in
            DispatchQueue.main.async {
                self?.appState.networkState = state
            }
        }

        // 3. 设置多设备踢下线事件
        client.onGoaway = { [weak self] _ in
            DispatchQueue.main.async {
                // 需要重新认证
                self?.appState.route = .welcome
                self?.appState.userInfo = nil
            }
        }

        // 4. 尝试恢复会话
        if let (aliasId, nickname) = try? await client.auth.restoreSession() {
            appState.userInfo = UserInfo(aliasId: aliasId, nickname: nickname)
            try? await client.connect()
            appState.sdkReady = true
            appState.route = .main
        } else {
            appState.route = .welcome
        }
    }
}
```

## 步骤 4: 认证流程

### 新用户注册（SetNicknameView.swift）

```swift
import SecureChatSDK

private func registerAccount() {
    isLoading = true
    errorMessage = nil

    Task {
        do {
            let client = SecureChatClient.shared
            
            // 调用 SDK 注册
            let aliasId = try await client.auth.registerAccount(
                mnemonic: mnemonicInput,  // 12 词
                nickname: nickname
            )

            // 建立 WebSocket 连接
            try await client.connect()

            // 更新状态
            appState.userInfo = UserInfo(aliasId: aliasId, nickname: nickname)
            appState.sdkReady = true
            appState.route = .main

        } catch {
            errorMessage = "注册失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
```

### 账户恢复（RecoverView.swift）

```swift
import SecureChatSDK

private func restoreAccount() {
    isLoading = true
    errorMessage = nil

    Task {
        do {
            let client = SecureChatClient.shared

            // 验证并恢复助记词
            let (aliasId, nickname) = try await client.auth.restoreSession(
                mnemonic: mnemonicInput
            )

            // 建立连接
            try await client.connect()

            appState.userInfo = UserInfo(aliasId: aliasId, nickname: nickname)
            appState.sdkReady = true
            appState.route = .main

        } catch {
            errorMessage = "恢复失败: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
```

## 步骤 5: 消息收发

### 发送消息（ChatView.swift）

```swift
import SecureChatSDK

private func sendMessage() {
    guard !messageText.isEmpty else { return }
    
    let text = messageText
    messageText = ""

    Task {
        do {
            let client = SecureChatClient.shared
            
            // SDK 会自动加密并发送
            try await client.messaging.send(
                conversationId: conversationId,
                text: text,
                mediaUrl: nil,  // 可选：媒体 URL
                mediaType: nil  // 可选：媒体类型
            )

            // 消息发送成功，SDK 会触发 onMessage 回调
        } catch {
            // 处理发送错误
            print("发送失败: \(error)")
        }
    }
}
```

### 接收消息（Navigation.swift）

```swift
// 在 AppNavigation 的 LaunchedEffect 中
DisposableEffect(Unit) {
    let subscription = client.onMessage = { msg in
        DispatchQueue.main.async {
            // msg.conversationId — 会话 ID
            // msg.text — 解密后的消息文本
            // msg.isMe — 是否是自己发送
            // msg.timestamp — 时间戳

            if appState.activeChatId != msg.conversationId {
                appState.incrementUnread(msg.conversationId)
            }
            // UI 会自动更新
        }
    }
    onDispose {
        // 订阅清理
    }
}
```

## 步骤 6: 好友管理

### 获取好友列表

```swift
import SecureChatSDK

func loadFriends() async {
    do {
        let client = SecureChatClient.shared
        let friends = try await client.contacts.syncFriends()
        
        // 更新 UI
        DispatchQueue.main.async {
            self.friends = friends
        }
    } catch {
        print("加载好友失败: \(error)")
    }
}
```

### 搜索用户

```swift
func searchUser(aliasId: String) async -> User? {
    do {
        let client = SecureChatClient.shared
        return try await client.contacts.lookupUser(aliasId: aliasId)
    } catch {
        return nil
    }
}
```

### 发送好友请求

```swift
func addFriend(aliasId: String) async {
    do {
        let client = SecureChatClient.shared
        try await client.contacts.sendFriendRequest(toAliasId: aliasId)
    } catch {
        print("发送好友请求失败: \(error)")
    }
}
```

## 步骤 7: 安全码验证

### 获取安全码

```swift
import SecureChatSDK

func getSecurityCode(conversationId: String) async -> String? {
    do {
        let client = SecureChatClient.shared
        return try await client.security.getSecurityCode(conversationId: conversationId)
    } catch {
        return nil
    }
}
```

### 验证安全码

```swift
func verifySecurityCode(conversationId: String, peerCode: String) async -> Bool {
    do {
        let client = SecureChatClient.shared
        return try await client.security.verifySecurityCode(
            conversationId: conversationId,
            peerCode: peerCode
        )
    } catch {
        return false
    }
}
```

## 步骤 8: 生成助记词（使用 SDK）

### 替换 Helpers.swift 中的 generateMnemonic()

```swift
import SecureChatSDK

func generateMnemonic() -> String {
    // 使用 SDK 的密钥派生模块
    return SecureChatSDK.KeyDerivation.newMnemonic()
}
```

## 步骤 9: 生成 QR 码（使用 SDK）

```swift
import SecureChatSDK

func generateQRCode(aliasId: String) -> UIImage? {
    let deeplink = "securechat://add?aliasId=\(aliasId)"
    // 使用系统 CoreImage 或 SDK 的 QR 生成
    return generateQRCode(from: deeplink)
}
```

## 步骤 10: 推送通知

### 请求推送权限

```swift
import UserNotifications

func requestPushNotification() async {
    do {
        let permission = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        if permission {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    } catch {
        print("推送权限请求失败: \(error)")
    }
}
```

### 在 SceneDelegate 中处理远程通知

```swift
func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
) {
    // 处理应用启动时的推送
    if let userActivity = connectionOptions.userActivities.first,
       userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let incomingURL = userActivity.webpageURL {
        // 处理深链接
    }
}

// 在 App 委托中
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
}
```

## 故障排查

### 问题 1: SDK 包不出现在 Link Binary 中

**解决方案：**
1. 清理构建文件夹：**Cmd+Shift+K**
2. 删除 Derived Data：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```
3. 重新打开项目

### 问题 2: "找不到模块 SecureChatSDK"

**解决方案：**
1. 检查 `sdk-ios/Package.swift` 是否存在
2. 验证相对路径是否正确
3. 检查 Build Phases → Link Binary With Libraries 中是否有 SDK
4. 在 Target → Build Settings → Framework Search Paths 中添加路径

### 问题 3: 运行时 SDK 初始化失败

**解决方案：**
1. 检查 WebSocket 连接（NetworkState）
2. 确保助记词有效
3. 验证 API 服务器 URL 正确（应该是 `relay.daomessage.com`）

### 问题 4: 消息无法发送

**解决方案：**
1. 确认 `appState.sdkReady == true`
2. 检查网络连接状态
3. 验证 `conversationId` 是否正确
4. 检查消息文本不为空

## 测试清单

- [ ] SDK 包成功添加到项目
- [ ] 编译无错误和警告
- [ ] 应用启动成功
- [ ] 新用户注册成功
- [ ] 用户可以恢复账户
- [ ] 消息可以发送和接收
- [ ] 未读计数正确更新
- [ ] 网络断开时显示提示
- [ ] 重新连接时自动恢复
- [ ] 深色模式正常显示

## 部署清单

在提交 App Store 之前：

- [ ] 所有硬编码的 URL 更新为生产环境
- [ ] 调试日志已移除
- [ ] 推送证书已配置
- [ ] App ID 和 Team ID 已设置
- [ ] 隐私政策已撰写
- [ ] 应用图标已添加
- [ ] 最低部署目标设置为 iOS 16
- [ ] 所有依赖已验证

## 参考文档

- [SwiftUI 官方文档](https://developer.apple.com/documentation/swiftui)
- [Xcode 帮助](https://help.apple.com/xcode)
- [iOS App Distribution](https://developer.apple.com/app-store/)
- SDK 文档（见 `sdk-ios/README.md`）
