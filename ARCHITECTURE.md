# iOS 应用架构设计文档

## 概述

DAO MESSAGE iOS 应用采用 **MVVM + @Observable** 架构，遵循 iOS 17+ 现代模式。所有业务逻辑委托给 SDK，App 层仅负责 UI 呈现和状态管理。

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                       │
│  (SwiftUI Views: WelcomeView, ChatView, MainView, etc.)     │
└────────────────────┬────────────────────────────────────────┘
                     │ reads/writes
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              State Management Layer (@Observable)             │
│  AppState: route, userInfo, activeChatId, unreadCounts, ... │
└────────────────────┬────────────────────────────────────────┘
                     │ calls
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    SDK Layer                                  │
│  SecureChatClient: auth, messaging, contacts, security, ... │
├─────────────────────────────────────────────────────────────┤
│  • 加密/解密（X25519-AES-GCM-256）                           │
│  • WebSocket 连接管理                                        │
│  • 离线消息队列                                              │
│  • 好友/频道数据持久化（IndexedDB 等价）                     │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP/WS
                     ▼
┌─────────────────────────────────────────────────────────────┐
│            Relay Server (Go backend)                         │
│  relay.daomessage.com:8080                                  │
└─────────────────────────────────────────────────────────────┘
```

## 核心模块

### 1. AppState (@Observable)

全局应用状态容器，被所有 View 订阅。

```swift
@Observable
final class AppState {
    // 导航
    var route: AppRoute = .welcome
    
    // 用户信息
    var userInfo: UserInfo? = nil
    var sdkReady = false
    
    // UI 状态
    var activeTab: MainTab = .messages
    var activeChatId: String? = nil
    
    // 数据
    var unreadCounts: [String: Int] = [:]
    var networkState: NetworkState = .disconnected(retryCount: 0)
    
    // 通话（可选）
    var callState: CallState? = nil
    
    // 好友申请计数
    var pendingFriendRequestCount: Int = 0
}
```

**特点：**
- 单一真相源（Single Source of Truth）
- 所有状态变化都通过此对象
- @Observable 自动触发 View 更新
- 线程安全的值类型

### 2. SecureChatClient (SDK)

提供业务逻辑的 SDK 单例。

```swift
let client = SecureChatClient.shared

// 认证模块
await client.auth.registerAccount(mnemonic, nickname)
await client.auth.restoreSession(mnemonic)
await client.auth.loginWithJWT(jwt)

// 消息模块
await client.messaging.send(conversationId, text)
await client.messaging.fetch(conversationId, limit)
await client.messaging.markRead(conversationId)

// 联系人模块
await client.contacts.syncFriends()
await client.contacts.lookupUser(aliasId)
await client.contacts.sendFriendRequest(aliasId)

// 安全码模块
await client.security.getSecurityCode(conversationId)
await client.security.verifySecurityCode(conversationId, peerCode)

// 频道模块
await client.channels.listChannels()
await client.channels.joinChannel(channelId)

// 事件监听
client.onMessage = { msg in ... }
client.onNetworkState = { state in ... }
client.onGoaway = { reason in ... }
client.onTyping = { info in ... }
```

### 3. 路由系统 (AppRoute)

控制应用的屏幕导航。

```swift
enum AppRoute: Hashable {
    case welcome           // 欢迎屏幕（新建/恢复选择）
    case generateMnemonic  // 生成 12 词
    case confirmBackup     // 验证助记词
    case vanityShop        // 购买靓号（可选）
    case setNickname       // 设置昵称并注册
    case recover           // 从助记词恢复
    case main              // 主界面（TabView）
}
```

**导航流程：**
```
welcome
  ├─→ generateMnemonic → confirmBackup → [vanityShop] → setNickname → main
  └─→ recover → [setNickname if new user] → main
```

### 4. View 层分类

#### A. Onboarding Views（注册和恢复流程）

| View | 责任 | SDK 调用 |
|------|------|---------|
| WelcomeView | 新用户/恢复选择 | 生成助记词 |
| GenerateMnemonicView | 显示 12 词，要求备份 | (无) |
| ConfirmBackupView | 验证用户记住助记词 | (无) |
| SetNicknameView | 输入昵称，调用注册 | `registerAccount()` |
| RecoverView | 输入助记词恢复 | `restoreSession()` |
| VanityShopView | 购买靓号（可选） | (支付 API) |

#### B. Main Views（主应用）

| View | 责任 | SDK 调用 |
|------|------|---------|
| MainView | TabView 容器 | (无) |
| MessagesTab | 会话列表 | `syncFriends()` |
| ChannelsTab | 频道列表 | `listChannels()` |
| ContactsTab | 联系人搜索/添加 | `lookupUser()`, `sendFriendRequest()` |
| ChatView | 消息发送/接收/显示 | `send()`, `onMessage` 事件 |
| SettingsView | 用户账户管理 | (无关键 SDK 调用) |

#### C. Helper Views（组件）

| Component | 用途 |
|-----------|------|
| MessageBubble | 消息气泡（自己/对方） |
| ChatHeaderBar | 聊天顶栏 |
| ChatInputBar | 消息输入栏 |
| SecurityVerifyView | 安全码核验 Modal |
| NetworkBanner | 网络状态提示 |
| CallOverlayView | 通话浮层 |

## 数据流

### 发送消息

```
ChatView (用户输入)
    ↓
messageText = "Hello"
    ↓
sendMessage() 被调用
    ↓
client.messaging.send(
    conversationId: "conv1",
    text: "Hello"
)
    ↓
SDK 加密 + WS 发送
    ↓
Relay Server 转发
    ↓
对方接收 + 解密
    ↓
触发 client.onMessage 回调
    ↓
AppState.incrementUnread() 或直接更新 messages 列表
    ↓
ChatView 重新渲染（@Observable 自动更新）
```

### 接收消息

```
Relay Server → SDK WebSocket
    ↓
SDK 解密消息
    ↓
触发 client.onMessage 回调
    ↓
DispatchQueue.main.async {
    if activeChatId != msg.conversationId {
        appState.incrementUnread(msg.conversationId)
    } else {
        // 直接添加到 messages 数组（ChatView 中）
    }
}
    ↓
View 自动重新渲染
```

### 网络状态变化

```
SDK 连接状态变化
    ↓
触发 client.onNetworkState 回调
    ↓
DispatchQueue.main.async {
    appState.networkState = state
}
    ↓
NetworkBanner 检测到状态变化
    ↓
自动显示/隐藏连接提示
```

## 状态转换图

```
AppState.route 转换：

welcome
├─ [选择新建] ──→ generateMnemonic
│                 └─ confirmBackup
│                   └─ setNickname (registerAccount)
│                     └─ main
│
└─ [选择恢复] ──→ recover (restoreSession)
                 └─ main
```

## 线程安全

所有 UI 更新必须在主线程执行：

```swift
// ❌ 错误
client.onMessage = { msg in
    appState.unreadCounts[msg.conversationId] = 1
}

// ✅ 正确
client.onMessage = { msg in
    DispatchQueue.main.async {
        appState.unreadCounts[msg.conversationId] = 1
    }
}
```

## 内存管理

### Weak Self in Closures

```swift
// ❌ 可能导致循环引用
self.client.onMessage = { msg in
    self.appState.route = .main
}

// ✅ 使用 [weak self]
.onReceive(publisher) { [weak self] value in
    guard let self = self else { return }
    self.appState.route = .main
}
```

### Task 生命周期

```swift
struct MyView: View {
    @State var appState: AppState
    
    var body: some View {
        VStack { ... }
            .task {
                // 在 View 加载时执行
                await loadData()
                // 在 View 卸载时自动取消
            }
    }
}
```

## 错误处理

所有 SDK 调用都应使用 try-catch 并显示用户友好的错误提示：

```swift
private func sendMessage() {
    Task {
        do {
            try await client.messaging.send(
                conversationId: conversationId,
                text: messageText
            )
            messageText = ""
        } catch {
            // 显示错误 Alert
            showError = true
            errorMessage = error.localizedDescription
        }
    }
}
```

## 测试策略

### 单元测试

```swift
// 测试 AppState
func testUnreadCounting() {
    var state = AppState()
    state.incrementUnread("conv1")
    state.incrementUnread("conv1")
    XCTAssertEqual(state.unreadCounts["conv1"], 2)
}

// 测试验证函数
func testMnemonicValidation() {
    let valid = "word1 word2 ... word12"
    XCTAssertTrue(validateMnemonic(valid))
    
    let invalid = "word1 word2"
    XCTAssertFalse(validateMnemonic(invalid))
}
```

### 集成测试

```swift
// 测试注册流程
func testRegistrationFlow() async {
    let client = SecureChatClient.shared
    let mnemonic = generateMnemonic()
    
    let aliasId = try await client.auth.registerAccount(
        mnemonic: mnemonic,
        nickname: "TestUser"
    )
    
    XCTAssertTrue(aliasId.starts(with: "u"))
}

// 测试消息发送
func testSendMessage() async {
    let client = SecureChatClient.shared
    try await client.messaging.send(
        conversationId: "test_conv",
        text: "Hello"
    )
    // 验证 onMessage 回调是否被触发
}
```

### UI 测试

```swift
// 测试欢迎屏幕
func testWelcomeViewLayout() {
    let screen = WelcomeView(appState: AppState())
    
    XCTAssertTrue(screen.body contains "DAO MESSAGE")
    XCTAssertTrue(screen.body contains "新建账户" button)
    XCTAssertTrue(screen.body contains "恢复账户" button)
}
```

## 性能优化

### 1. 消息列表虚拟化

```swift
// 仅渲染可见消息
ScrollView {
    LazyVStack {
        ForEach(messages) { message in
            MessageBubble(message: message)
        }
    }
}
```

### 2. 图片加载优化

```swift
AsyncImage(url: imageUrl) { phase in
    switch phase {
    case .success(let image):
        image.resizable()
    case .loading:
        ProgressView()
    case .empty, .failure:
        Image(systemName: "photo")
    @unknown default:
        EmptyView()
    }
}
```

### 3. 避免重复渲染

```swift
// 使用 .id() 确保 View 能正确识别变化
ForEach(messages, id: \.id) { message in
    MessageBubble(message: message)
        .id(message.id)
}
```

## 安全最佳实践

### 1. 助记词处理

```swift
// ❌ 不要打印或存储
print(mnemonic)  // 危险！

// ✅ 只通过 SDK 处理
let aliasId = try await client.auth.registerAccount(
    mnemonic: mnemonic,
    nickname: nickname
)
// 忘记 mnemonic 变量
```

### 2. JWT 管理

```swift
// ❌ 不要在代码中硬编码 JWT
let jwt = "eyJhbGc..."  // 危险！

// ✅ 让 SDK 处理认证
let isAuth = try await client.auth.restoreSession()
```

### 3. TLS/SSL 验证

SDK 应自动验证服务器证书。确认没有禁用证书验证：

```swift
// ❌ 危险
let config = URLSessionConfiguration.default
config.waitsForConnectivity = false

// ✅ 安全
let config = URLSessionConfiguration.default
// (使用系统默认的 TLS 验证)
```

## 部署清单

- [ ] 所有 hardcode URL 更新为生产环境
- [ ] 调试日志移除
- [ ] SDK 版本锁定到特定版本
- [ ] App Transport Security 设置（只允许 HTTPS）
- [ ] 推送通知证书配置
- [ ] App Store 应用凭证配置
- [ ] 应用图标和启动屏幕就位
- [ ] 隐私政策已撰写
- [ ] 最低部署目标设置为 iOS 16

## 文件大小和兼容性

| 组件 | 大小估计 |
|------|--------|
| App Bundle | ~15-20 MB |
| SDK | ~2-3 MB |
| Assets | ~1-2 MB |
| **总计** | **~20-25 MB** |

App Store 限制：150 MB（包括 on-demand resources）

## 下一步扩展

1. **语音/视频通话**：集成 WebRTC，使用 SDK 的信令模块
2. **文件传输**：实现媒体上传/下载，使用 SDK 的 media 模块
3. **群聊**：扩展消息 API 支持群组对话
4. **消息搜索**：实现全文搜索（本地或通过 SDK）
5. **推送通知**：集成 APNs，处理后台消息
6. **离线消息**：SDK 应自动队列化，重连时重发

---

**最后更新**: 2026-04-15  
**维护者**: DAO MESSAGE Team
