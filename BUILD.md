# 构建和部署指南

## 本地开发环境设置

### 1. 系统要求

- macOS 12.0 或更高版本
- Xcode 15.0 或更高版本
- iOS 16+ 为部署目标
- Swift 5.9 或更高版本

### 2. 克隆和设置

```bash
# 克隆项目
git clone <repo-url>
cd chat

# 导航到 iOS 应用
cd template-app-ios/SecureChatTemplate

# 打开 Xcode
open SecureChatTemplate.xcodeproj
```

### 3. Xcode 配置

**Project Settings:**
- Product Name: `SecureChatTemplate`
- Bundle Identifier: `space.securechat.template`
- Team ID: `<Your Team ID>`
- Signing Certificate: Select your development certificate
- Minimum Deployment Target: `iOS 16.0`

**Target Settings:**
1. Select target `SecureChatTemplate`
2. Build Settings:
   ```
   Swift Language Version: 5.9
   Swift Compiler - Language: Enable Module Verifier: No
   ```

### 4. SDK 依赖

在 Xcode 中添加本地 SDK 包：

```
File → Add Packages
```

选择 `../sdk-ios` 目录

验证 Build Phases 中 `Link Binary With Libraries` 包含 `SecureChatSDK`

## 构建和运行

### 开发构建

```bash
# 使用 Xcode UI 或命令行

# 清理
xcodebuild clean

# 构建
xcodebuild -scheme SecureChatTemplate -configuration Debug

# 运行模拟器（iOS 16）
xcodebuild -scheme SecureChatTemplate \
    -destination 'generic/platform=iOS Simulator,name=iPhone 15'
```

### 调试模式

在 Xcode 中：
1. 选择目标设备或模拟器
2. Product → Run（⌘R）
3. 使用 Debug Navigator（⌘6）查看日志

### 测试构建

```bash
# 运行所有单元测试
xcodebuild test -scheme SecureChatTemplate

# 运行特定测试
xcodebuild test -scheme SecureChatTemplate \
    -only-testing SecureChatTemplateTests/AppStateTests
```

## 打包和发布

### 生成存档（Archive）

```bash
# 命令行方式
xcodebuild archive \
    -scheme SecureChatTemplate \
    -archivePath ./build/SecureChatTemplate.xcarchive \
    -configuration Release

# 或使用 Xcode UI
# Product → Archive
```

### 导出 IPA

```bash
# 为 App Store 导出
xcodebuild -exportArchive \
    -archivePath ./build/SecureChatTemplate.xcarchive \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath ./build/

# ExportOptions.plist 内容：
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
# <plist version="1.0">
# <dict>
#     <key>signingStyle</key>
#     <string>automatic</string>
#     <key>teamID</key>
#     <string>YOUR_TEAM_ID</string>
#     <key>method</key>
#     <string>app-store</string>
#     <key>stripSwiftSymbols</key>
#     <true/>
# </dict>
# </plist>
```

### App Store 提交

#### 前置条件

1. **Apple Developer 账户**：https://developer.apple.com
2. **App ID 和 Bundle Identifier**：在 Apple Developer Portal 创建
3. **推送证书**（可选）：如果使用推送通知
4. **App 图标**：1024x1024 PNG，不包含圆角或 alpha
5. **启动屏幕**：2560x1440（或使用 LaunchScreen.storyboard）
6. **隐私政策**：URL 或内联文本
7. **应用描述**：100-170 个字符
8. **关键词**：最多 5 个，用逗号分隔
9. **支持网址和技术支持**

#### 上传到 App Store Connect

```bash
# 使用 Xcode Organizer
# 1. Product → Archive
# 2. 点击 Distribute App
# 3. 选择 App Store
# 4. 选择 Upload
# 5. 选择证书和配置文件
# 6. 上传

# 或使用 xcrun altool
xcrun altool --upload-app \
    --file SecureChatTemplate.ipa \
    --type ios \
    --apiKey [APPLE_KEY_ID] \
    --apiIssuer [APPLE_ISSUER_ID]
```

### 测试飞行 (TestFlight)

```bash
# TestFlight 用于 Beta 测试
# 在 App Store Connect 中：
# 1. TestFlight → iOS 构建
# 2. 上传存档后自动显示
# 3. 添加测试者（邮箱）
# 4. 共享公开链接供 Beta 测试者安装
```

## 代码签名

### 自动签名（推荐）

Xcode 默认配置自动签名。确保：

```
Team ID: 设置为有效值
Signing Certificate: 自动
Provisioning Profile: 自动
```

### 手动签名

如果自动签名失败：

```bash
# 列出可用证书
security find-identity -v -p codesigning

# 指定证书
xcodebuild -scheme SecureChatTemplate \
    -configuration Release \
    CODE_SIGN_IDENTITY="Apple Development" \
    PROVISIONING_PROFILE_SPECIFIER="SecureChat Development Profile"
```

## 环境配置

### Debug vs Release

**Debug Build:**
```swift
#if DEBUG
let apiURL = "https://relay-dev.daomessage.com"
#else
let apiURL = "https://relay.daomessage.com"
#endif
```

**Info.plist:**
```xml
<!-- 开发环境允许 HTTP（仅限调试） -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## 性能优化

### App 启动时间

```swift
// 延迟初始化非关键模块
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    // 初始化分析、崩溃报告等
}
```

### 内存管理

```bash
# 检查内存泄漏
xcodebuild test -scheme SecureChatTemplate \
    -destination generic/platform=iOS \
    -only-testing SecureChatTemplateTests
```

### 编译优化

在 Build Settings 中：
```
Optimization Level: Fastest, Smallest
```

## 持续集成 (CI/CD)

### GitHub Actions 示例

```yaml
name: iOS Build

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build
        run: |
          xcodebuild -scheme SecureChatTemplate \
              -destination 'generic/platform=iOS' \
              clean build
      
      - name: Test
        run: |
          xcodebuild test -scheme SecureChatTemplate \
              -destination 'platform=iOS Simulator,name=iPhone 15'
      
      - name: Archive
        run: |
          xcodebuild archive \
              -scheme SecureChatTemplate \
              -archivePath build/SecureChatTemplate.xcarchive
```

### fastlane 自动化

```ruby
# Fastfile
default_platform(:ios)

platform :ios do
  desc "Build and test"
  lane :build do
    build_app(
      scheme: "SecureChatTemplate",
      configuration: "Debug",
      destination: "generic/platform=iOS Simulator",
      derived_data_path: "build"
    )
  end

  desc "Beta release to TestFlight"
  lane :beta do
    build_app(
      scheme: "SecureChatTemplate",
      configuration: "Release",
      archive: true,
      export_method: "app-store"
    )
    
    upload_to_testflight(
      app_identifier: "space.securechat.template"
    )
  end

  desc "Release to App Store"
  lane :release do
    build_app(
      scheme: "SecureChatTemplate",
      configuration: "Release",
      archive: true,
      export_method: "app-store"
    )
    
    deliver(
      app_identifier: "space.securechat.template",
      skip_screenshots: true,
      skip_metadata: true
    )
  end
end
```

## 故障排查

### 常见问题

#### Q1: "找不到开发团队"

```
A: 在 Signing & Capabilities 标签中：
   1. 选择 Team
   2. 取消勾选并重新勾选 "Automatically manage signing"
```

#### Q2: "证书失效或过期"

```
A: 在 Keychain Access 中删除过期证书：
   1. 打开 Keychain Access
   2. 搜索 "Apple"
   3. 删除过期证书
   4. 在 Xcode 中重新下载
```

#### Q3: "构建失败：找不到 SDK"

```
A: 
   1. 检查 SDK 路径相对位置正确
   2. 清理构建文件夹：Cmd+Shift+K
   3. 删除 Derived Data：rm -rf ~/Library/Developer/Xcode/DerivedData
   4. 重新打开项目
```

#### Q4: "模拟器运行缓慢"

```
A: 
   1. 清理模拟器：xcrun simctl erase all
   2. 重启模拟器：xcrun simctl shutdown all
   3. 使用真机测试
   4. 升级 macOS 和 Xcode
```

## 安全检查清单

- [ ] 所有 API 调用使用 HTTPS
- [ ] 没有硬编码密钥或令牌
- [ ] 敏感数据存储在 Keychain
- [ ] App Transport Security 启用
- [ ] 证书正确配置
- [ ] 代码签名验证
- [ ] 没有调试符号在生产构建中
- [ ] 推送通知证书有效

## 监控和分析

### 崩溃报告

集成 Firebase Crashlytics 或类似服务：

```swift
import FirebaseCrashlytics

// 在 AppDelegate 中
FirebaseApp.configure()
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
```

### 分析

```swift
import FirebaseAnalytics

// 跟踪事件
Analytics.logEvent("message_sent", parameters: [
    "conversation_id": conversationId,
    "message_length": messageText.count
])
```

### 性能监控

```swift
import FirebasePerformance

let trace = Performance.startTrace(name: "message_send")
// ... 执行操作
trace?.stop()
```

## 发布清单

**发布前 1 周：**
- [ ] 版本号更新（Info.plist）
- [ ] 发布说明已撰写
- [ ] 所有测试通过
- [ ] 代码审查完成

**发布前 3 天：**
- [ ] TestFlight 上线测试
- [ ] 收集反馈和错误报告
- [ ] 修复关键 bug

**发布前 1 天：**
- [ ] 最终测试通过
- [ ] App Store 描述和关键词已编辑
- [ ] 截图已准备（5 个最小）

**发布当天：**
- [ ] 创建最终存档
- [ ] 上传到 App Store Connect
- [ ] 填写发布说明
- [ ] 提交审核

**发布后：**
- [ ] 监控崩溃和性能指标
- [ ] 回复用户评论
- [ ] 准备下一个版本

## 版本管理

```swift
// Info.plist
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>

// 在代码中访问
if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
    print("App Version: \(version)")
}
```

## 支持

遇到问题？

1. 查看 [INTEGRATION.md](INTEGRATION.md)
2. 查看 [ARCHITECTURE.md](ARCHITECTURE.md)
3. 检查 Xcode 构建日志
4. 尝试清理并重建
5. 参考 Apple 官方文档

---

**最后更新**: 2026-04-15
