//
//  Navigation.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import SecureChatSDK

#if canImport(WebRTC)
import WebRTC
#endif

/// 主导航容器 — 根据 appState.route 展示对应屏幕
struct NavigationView: View {
    @State var appState: AppState

    var body: some View {
        ZStack {
            // 根据路由显示对应屏幕
            switch appState.route {
            case .welcome:
                WelcomeView(appState: appState)
            case .generateMnemonic:
                GenerateMnemonicView(appState: appState)
            case .confirmBackup:
                ConfirmBackupView(appState: appState)
            case .vanityShop:
                VanityShopView(appState: appState)
            case .setNickname:
                SetNicknameView(appState: appState)
            case .recover:
                RecoverView(appState: appState)
            case .main:
                MainView(appState: appState)
            }

            // 网络状态横幅（overlay）
            if case .disconnected = appState.networkState {
                VStack {
                    NetworkBanner(state: appState.networkState)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
            }

            // 通话浮层（由 CallManager 自行管理显示/隐藏）
            CallManagerOverlay()
        }
        // 监听 APNS deeplink — 点击推送跳到对应会话
        .onReceive(NotificationCenter.default.publisher(for: .openConversation)) { note in
            if let convId = note.object as? String, !convId.isEmpty {
                appState.activeChatId = convId
                appState.clearUnread(convId)
            }
        }
        // GOAWAY 全屏弹窗 — 被新设备挤下线
        .alert("Logged out", isPresented: $appState.showGoaway) {
            Button("OK") {
                appState.showGoaway = false
                Task {
                    try? await SecureChatClient.shared().logout()
                }
                appState.route = .welcome
                appState.userInfo = nil
                appState.sdkReady = false
            }
        } message: {
            Text("Your account was logged in on another device. For security, only one device can be active at a time.")
        }
    }
}

// MARK: - Network Banner
// 注：NetworkBanner 定义已迁至独立文件 NetworkBanner.swift

// MARK: - Call Overlay

/// 通话全屏覆盖层 — 对标 Android CallScreen.kt
struct CallOverlayView: View {
    @State var appState: AppState

    var body: some View {
        CallManagerOverlay()
    }
}

struct CallManagerOverlay: View {
    var callManager = CallManager.shared
    @State private var elapsedSec: Int = 0
    @State private var ticker: Timer? = nil

    var body: some View {
        Group {
            if callManager.state != .idle, let info = callManager.info {
                ZStack {
                    Color.black.ignoresSafeArea()

                    // 远端视频 / 或 头像
                    #if canImport(WebRTC)
                    if info.mode == .video, let track = callManager.remoteVideoTrackForRender {
                        RTCVideoViewRepresentable(track: track, isLocal: false)
                            .ignoresSafeArea()
                    } else {
                        bigAvatar(info: info)
                    }
                    #else
                    bigAvatar(info: info)
                    #endif

                    // 本地小窗
                    #if canImport(WebRTC)
                    if info.mode == .video, let local = callManager.localVideoTrackForRender {
                        VStack {
                            HStack {
                                Spacer()
                                RTCVideoViewRepresentable(track: local, isLocal: true)
                                    .frame(width: 110, height: 160)
                                    .cornerRadius(12)
                                    .padding(.top, 48)
                                    .padding(.trailing, 16)
                            }
                            Spacer()
                        }
                    }
                    #endif

                    VStack {
                        Spacer().frame(height: 60)
                        Text("@\(info.remoteAlias)")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                        Text(statusText)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()

                        // 按钮区
                        HStack(spacing: 30) {
                            if callManager.state == .incoming {
                                callButton(icon: "phone.down.fill", color: DangerColor, label: "拒接") {
                                    callManager.reject()
                                }
                                callButton(icon: "phone.fill", color: Color.green, label: "接听") {
                                    callManager.answer()
                                }
                            } else {
                                callButton(icon: callManager.micMuted ? "mic.slash.fill" : "mic.fill",
                                           color: callManager.micMuted ? .gray : Color.white.opacity(0.25),
                                           label: callManager.micMuted ? "Unmute" : "Mute") {
                                    callManager.toggleMic()
                                }
                                callButton(icon: "phone.down.fill", color: DangerColor, label: "挂断") {
                                    callManager.hangup()
                                }
                                if info.mode == .video {
                                    callButton(icon: callManager.cameraMuted ? "video.slash.fill" : "video.fill",
                                               color: callManager.cameraMuted ? .gray : Color.white.opacity(0.25),
                                               label: callManager.cameraMuted ? "Cam On" : "Cam Off") {
                                        callManager.toggleCamera()
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 48)
                    }
                }
                .onAppear { startTicker() }
                .onDisappear { stopTicker() }
                .onChange(of: callManager.state) { _, newState in
                    if newState == .connected { startTicker() }
                    if newState == .idle { stopTicker() }
                }
            }
        }
    }

    private var statusText: String {
        switch callManager.state {
        case .outgoing:   return "呼叫中…"
        case .incoming:   return "来电：\(callManager.info?.mode.rawValue ?? "")"
        case .connecting: return "连接中…"
        case .connected:  return String(format: "%d:%02d", elapsedSec / 60, elapsedSec % 60)
        case .ended:      return "已结束"
        case .idle:       return ""
        }
    }

    @ViewBuilder
    private func bigAvatar(info: CallInfo) -> some View {
        VStack {
            ZStack {
                Circle().fill(BlueAccent.opacity(0.25))
                    .frame(width: 140, height: 140)
                Text(info.remoteAlias.prefix(2).uppercased())
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    @ViewBuilder
    private func callButton(icon: String, color: Color, label: String, onTap: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: onTap) {
                ZStack {
                    Circle().fill(color).frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            Text(label).font(.system(size: 12)).foregroundColor(.gray)
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        elapsedSec = 0
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSec += 1
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}

#if canImport(WebRTC)
/// SwiftUI 桥接 WebRTC 的视频渲染视图
struct RTCVideoViewRepresentable: UIViewRepresentable {
    let track: RTCVideoTrack
    let isLocal: Bool

    func makeUIView(context: Context) -> UIView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        track.add(view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // track 更换时 add 新视图
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        if let v = uiView as? RTCMTLVideoView {
            // 释放时 SDK 会自动清理
            _ = v
        }
    }
}
#endif

#Preview {
    NavigationView(appState: AppState())
}
