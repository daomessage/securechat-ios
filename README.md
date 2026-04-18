# SecureChat iOS App - Template

生产级别的 SwiftUI 即时通讯应用参考实现，展示了与 DAO MESSAGE SDK 的集成。

## 特性

- ✅ **完整 Onboarding 流程** — 新建账户、恢复账户、助记词备份验证
- ✅ **4 个主 Tab** — 消息、频道、联系人、设置
- ✅ **实时聊天** — 消息发送、接收、未读计数、输入状态提示
- ✅ **端对端加密** — 所有通信均通过 SDK 加密（X25519-AES-GCM-256）
- ✅ **安全码验证** — 首次聊天时验证身份
- ✅ **暗黑模式** — 完全支持 iOS 深色模式
- ✅ **网络状态管理** — 连接状态提示、自动重连机制
- ✅ **设备适配** — iOS 16+ 全屏幕尺寸支持

## 项目结构

```
SecureChatTemplate/
├── SecureChatTemplateApp.swift      # App 入口，SDK 初始化
├── AppState.swift                   # @Observable 全局状态管理
├── Navigation.swift                 # 主导航容器 + 网络/通话浮层
├── Theme.swift                      # 颜色、字体、间距常量
├── Helpers.swift                    # 工具函数（验证、加密、时间格式化）
│
├── onboarding/
│   ├── WelcomeView.swift            # 欢迎屏幕（新建/恢复）
│   ├── GenerateMnemonicView.swift   # 生成并展示 12 词
│   ├── ConfirmBackupView.swift      # 验证助记词记忆
│   ├── SetNicknameView.swift        # 设置昵称并注册
│   ├── RecoverView.swift            # 从助记词恢复账户
│   └── VanityShopView.swift         # 购买靓号（可选）
│
├── main/
│   ├── MainView.swift               # TabView 主界面（消息/频道/联系人/设置）
│
├── messages/
│   ├── MessagesTab.swift            # 会话列表（已包含在 MainView）
│
├── contacts/
│   ├── ContactsTab.swift            # 联系人列表 + 添加好友（已包含在 MainView）
│
├── channels/
│   ├── ChannelsTab.swift            # 频道列表（已包含在 MainView）
│
├── chat/
│   ├── ChatView.swift               # 聊天界面（消息列表 + 输入栏 + 安全码验证）
│
└── settings/
    └── SettingsView.swift           # 设置屏幕（用户信息 + 加密状态 + 账户管理）
```

## 快速开始

### 1. 打开项目

```bash
cd template-app-ios/SecureChatTemplate
open SecureChatTemplate.xcodeproj
```

### 2. 添加 SDK 依赖

在 Xcode 中：
1. File → Add Packages
2. 输入本地路径：`../../../sdk-ios`（相对于项目根目录）
3. 选择 "Add to SecureChatTemplate"

或手动编辑 `SecureChatTemplate.xcodeproj` 中的 Build Phases → Link Binary With Libraries

### 3. 运行

```bash
# 使用 Xcode
xcodebuild -scheme SecureChatTemplate -destination 'generic/platform=iOS'

# 或直接在 Xcode 中运行模拟器
```

## SDK 集成指南

### 初始化（在 SecureChatTemplateApp.swift）

```swift
// 1. 导入 SDK
import SecureChatSDK

// 2. 在 setupSDKListeners() 中初始化
let client = SecureChatClient.shared

// 3. 设置事件监听
client.onMessage = { msg in
    DispatchQueue.main.async {
        appState.incrementUnread(msg.conversationId)
    }
}

client.onNetworkState = { state in
    DispatchQueue.main.async {
        appState.networkState = state
    }
}
```

### 注册新账户（SetNicknameView.swift）

```swift
private func registerAccount() {
    Task {
        do {
            let aliasId = try await SecureChatClient.shared.auth.registerAccount(
                mnemonic: mnemonicInput,
                nickname: nickname
            )
            appState.userInfo = UserInfo(aliasId: aliasId, nickname: nickname)
            appState.route = .main
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### 恢复账户（RecoverView.swift）

```swift
private func restoreAccount() {
    Task {
        do {
            let (aliasId, nickname) = try await SecureChatClient.shared.auth.restoreSession(
                mnemonic: mnemonicInput
            )
            appState.userInfo = UserInfo(aliasId: aliasId, nickname: nickname)
            appState.route = .main
        } catch {
            errorMessage = "恢复失败：\(error.localizedDescription)"
        }
    }
}
```

### 发送消息（ChatView.swift）

```swift
private func sendMessage() {
    Task {
        do {
            try await SecureChatClient.shared.messaging.send(
                conversationId: conversationId,
                text: messageText
            )
            messageText = ""
        } catch {
            // 处理错误
        }
    }
}
```

### 监听新消息（NavigationView.swift）

```swift
.task {
    let subscription = SecureChatClient.shared.onMessage = { msg in
        DispatchQueue.main.async {
            if appState.activeChatId != msg.conversationId {
                appState.incrementUnread(msg.conversationId)
            }
        }
    }
}
```

## 状态管理

使用 `@Observable` 宏（iOS 17+）进行响应式状态管理：

```swift
@Observable
final class AppState {
    var route: AppRoute = .welcome           // 当前路由
    var userInfo: UserInfo? = nil            // 用户信息
    var activeChatId: String? = nil          // 打开的聊天 ID
    var unreadCounts: [String: Int] = [:]    // 未读计数
    var networkState: NetworkState = ...     // 网络状态
}

// 在 View 中使用
struct MyView: View {
    @State var appState: AppState
    
    var body: some View {
        Text("\(appState.totalUnread)条未读消息")
    }
}
```

## 主要视图组件

### Theme.swift — 设计系统

- **颜色**：DarkBg, Surface1, Surface2, BlueAccent, TextPrimary, TextMuted 等
- **间距**：Spacing8, Spacing12, Spacing16, Spacing20, Spacing24 等
- **圆角**：RadiusSmall, RadiusMedium, RadiusLarge, RadiusXL
- **按钮样式**：`PrimaryButtonStyle()`, `SecondaryButtonStyle()`

### Navigation.swift — 路由管理

- 根据 `appState.route` 动态渲染不同屏幕
- `NetworkBanner` — 网络状态提示
- `CallOverlayView` — 通话浮层

### AppState.swift — 数据模型

```swift
enum AppRoute {
    case welcome, generateMnemonic, confirmBackup, setNickname, recover, main
}

enum MainTab {
    case messages, channels, contacts, settings
}

@Observable
final class AppState {
    var route: AppRoute
    var userInfo: UserInfo?
    var activeTab: MainTab
    var activeChatId: String?
    var unreadCounts: [String: Int]
    var networkState: NetworkState
    // ...
}
```

## 与 Web 版对齐

本 iOS 实现遵循与 Web（React）版本相同的设计和逻辑：

| 功能 | iOS | Web (React) |
|-----|-----|-----------|
| 状态管理 | @Observable | Zustand store |
| 路由 | AppRoute enum | react-router |
| 主题 | Theme.swift | Tailwind CSS |
| Tab 导航 | TabView | Bottom Tab Bar |
| 聊天列表 | List | ScrollView |
| 消息气泡 | MessageBubble | Chat messages |

## 代码质量要求

- ✅ 所有 View 为独立文件（禁止内嵌 struct）
- ✅ 颜色/间距 从 Theme.swift 获取（禁止 hardcode）
- ✅ 异步操作用 `.task { }` 或 `Task { }` 
- ✅ 错误用 Alert 展示（禁止 crash）
- ✅ 支持深/浅色模式
- ✅ 使用 SF Symbols（系统图标）
- ✅ 关键逻辑附加中文注释

## 深色模式支持

所有颜色值都已针对深色模式优化。在 iOS 系统设置中切换深/浅色模式时会自动适应：

```swift
// Color 值已预设为深色调
let DarkBg = Color(red: 0.04, green: 0.04, blue: 0.05)
let Surface1 = Color(red: 0.09, green: 0.09, blue: 0.11)
```

如需支持浅色模式，需在 Info.plist 中修改 `UIUserInterfaceStyle` 并添加相应的浅色颜色值。

## 部署准备

### iOS 16+ 最低支持

在 `project.pbxproj` 中确保：

```
IPHONEOS_DEPLOYMENT_TARGET = 16.0;
```

### 无第三方依赖

仅依赖系统框架和 SDK 包：
- SwiftUI（系统）
- Foundation（系统）
- AVFoundation（摄像头、音频）
- CoreImage（QR 码生成）
- SecureChatSDK（本地 Swift Package）

### 签名和发布

```bash
# 构建 Archive
xcodebuild -scheme SecureChatTemplate -configuration Release archive

# 或使用 Xcode 的 Product → Archive
```

## 常见问题

### Q: 如何连接 SDK？

A: 在 Xcode 项目设置中：
1. 选择 SecureChatTemplate target
2. Build Phases → Link Binary With Libraries
3. 添加 SDK 本地包（../sdk-ios）

### Q: 消息没有发送？

A: 检查：
1. SDK 是否初始化（`appState.sdkReady`）
2. WebSocket 连接状态（`appState.networkState`）
3. 消息文本不为空
4. 网络连接正常

### Q: 助记词生成失败？

A: 确保 SDK 的 `KeyDerivation.newMnemonic()` 正确导入并实现。

## 下一步

1. **本地开发**：集成 SDK 包，测试完整注册/聊天流程
2. **功能扩展**：添加语音/视频通话、文件传输、群聊等
3. **性能优化**：消息列表虚拟化、图片加载优化
4. **单元测试**：为数据模型、验证函数编写测试
5. **App Store 发布**：获取 Team ID，设置推送证书，提交审核

## 许可证

DAO MESSAGE Protocol — Privacy First
