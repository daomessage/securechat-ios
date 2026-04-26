//
//  CallManager.swift
//  SecureChatTemplate
//
//  通话状态机 + WebRTC 媒体集成（GoogleWebRTC / stasel/WebRTC）
//  对标 Android CallManager.kt 与 PWA CallScreen.tsx
//
//  ⚠️ 使用前需在 Xcode 中通过 File → Add Packages 添加:
//     https://github.com/stasel/WebRTC  (分支 release/M129 或更新)
//
//  若暂未添加 WebRTC 包，信令/UI 状态机仍可工作（媒体流部分会 no-op）。
//

import Foundation
import AVFoundation
import SecureChatSDK

#if canImport(WebRTC)
import WebRTC
#endif

enum CallManagerState {
    case idle, outgoing, incoming, connecting, connected, ended
}

enum CallMode: String {
    case audio, video
}

struct CallInfo {
    let callId: String
    let remoteAlias: String
    let isCaller: Bool
    let mode: CallMode
    let startedAt: Date = Date()
}

@Observable
final class CallManager {

    static let shared = CallManager()

    var state: CallManagerState = .idle
    var info: CallInfo? = nil
    var micMuted: Bool = false
    var cameraMuted: Bool = false

    private var noAnswerTask: Task<Void, Never>? = nil
    private var client: SecureChatClient { SecureChatClient.shared() }

    #if canImport(WebRTC)
    // WebRTC
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory
        )
    }()

    private var peer: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var pendingIce: [RTCIceCandidate] = []

    var localVideoTrackForRender: RTCVideoTrack? { localVideoTrack }
    var remoteVideoTrackForRender: RTCVideoTrack? { remoteVideoTrack }
    #endif

    // ICE 配置 — 运行时从 /api/v1/calls/ice-config 动态拉取（Cloudflare Realtime TURN）
    // 失败时降级为 Google 公共 STUN
    private func fetchIceServers() async -> [RTCIceServer] {
        // SDK fetchTurnConfig() 返回服务端下发的 iceServers 数组
        if let turnConfig = try? await client.fetchTurnConfig() {
            let servers: [RTCIceServer] = turnConfig.iceServers.compactMap { srv in
                guard let urls = srv["urls"] as? [String], !urls.isEmpty else { return nil }
                let username   = srv["username"]   as? String
                let credential = srv["credential"] as? String
                if let u = username, let c = credential {
                    return RTCIceServer(urlStrings: urls, username: u, credential: c)
                }
                return RTCIceServer(urlStrings: urls)
            }
            if !servers.isEmpty {
                return servers
            }
        }
        // 降级：Google 公共 STUN
        return [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302",
                                          "stun:stun1.l.google.com:19302"])]
    }

    // MARK: - Lifecycle

    func start() {
        // 订阅来自 SDK 的通话信令帧（call_invite / call_offer / call_answer / call_ice / call_hangup 等）
        // start() 必须在 client.connect()（WS 建立）之后、且 UI 已准备好之前调用，
        // 确保第一条来电帧到达时回调已注册。
        // 对标 Android CallManager.start() / PWA App.tsx initCalls() 的信令注册时序。
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await client.on(SecureChatClient.EVENT_SIGNAL) { [weak self] frame in
                guard let frame = frame as? [String: Any] else { return }
                Task { @MainActor [weak self] in
                    self?.handleIncomingSignal(frame)
                }
            }
        }
    }

    // MARK: - Public API

    func call(to remoteAlias: String, mode: CallMode) {
        let callId = UUID().uuidString
        self.info = CallInfo(callId: callId, remoteAlias: remoteAlias, isCaller: true, mode: mode)
        self.state = .outgoing
        self.micMuted = false
        self.cameraMuted = false

        #if canImport(WebRTC)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let servers = await self.fetchIceServers()
            self.setupPeer(iceServerList: servers)
            self.attachLocalMedia(mode: mode)
            self.createOfferAndSend(mode: mode)
        }
        #endif

        sendSignal(type: "call_invite", extras: ["mode": mode.rawValue])

        noAnswerTask?.cancel()
        noAnswerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            await MainActor.run {
                if self?.state == .outgoing {
                    self?.hangup()
                }
            }
        }
    }

    func answer() {
        noAnswerTask?.cancel()
        guard let info = info, state == .incoming else { return }
        state = .connecting

        #if canImport(WebRTC)
        Task { @MainActor [weak self] in
            guard let self else { return }
            let servers = await self.fetchIceServers()
            self.setupPeer(iceServerList: servers)
            self.attachLocalMedia(mode: info.mode)
            // remote offer 已在 incoming 时 setRemoteDescription
            self.createAnswerAndSend()
            self.state = .connected
        }
        #else
        state = .connected
        #endif
    }

    func reject() {
        noAnswerTask?.cancel()
        sendSignal(type: "call_reject")
        teardown()
        state = .ended
        info = nil
        state = .idle
    }

    func hangup() {
        noAnswerTask?.cancel()
        sendSignal(type: "call_hangup")
        teardown()
        state = .ended
        info = nil
        state = .idle
    }

    func toggleMic() {
        micMuted.toggle()
        #if canImport(WebRTC)
        localAudioTrack?.isEnabled = !micMuted
        #endif
    }

    func toggleCamera() {
        cameraMuted.toggle()
        #if canImport(WebRTC)
        localVideoTrack?.isEnabled = !cameraMuted
        #endif
    }

    // MARK: - Incoming signaling

    func handleIncomingSignal(_ frame: [String: Any]) {
        guard let type = frame["type"] as? String,
              let from = frame["from"] as? String,
              let callId = frame["call_id"] as? String else { return }
        switch type {
        case "call_invite":
            guard state == .idle else {
                sendSignal(type: "call_reject", to: from, callId: callId)
                return
            }
            let mode: CallMode = (frame["mode"] as? String == "video") ? .video : .audio
            info = CallInfo(callId: callId, remoteAlias: from, isCaller: false, mode: mode)
            state = .incoming

        case "call_offer":
            #if canImport(WebRTC)
            if peer == nil {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let servers = await self.fetchIceServers()
                    self.setupPeer(iceServerList: servers)
                }
            }
            if let sdp = frame["sdp"] as? String {
                let desc = RTCSessionDescription(type: .offer, sdp: sdp)
                peer?.setRemoteDescription(desc, completionHandler: { [weak self] _ in
                    self?.flushPendingIce()
                })
            }
            #endif

        case "call_answer":
            #if canImport(WebRTC)
            if let sdp = frame["sdp"] as? String {
                let desc = RTCSessionDescription(type: .answer, sdp: sdp)
                peer?.setRemoteDescription(desc, completionHandler: { [weak self] _ in
                    self?.flushPendingIce()
                })
            }
            #endif
            if state == .outgoing { state = .connected }

        case "call_reject", "call_hangup":
            teardown()
            state = .ended
            info = nil
            state = .idle

        case "call_ice":
            #if canImport(WebRTC)
            guard let sdp = frame["candidate"] as? String else { return }
            let sdpMid = frame["sdp_mid"] as? String
            let sdpMLine = (frame["sdp_mline"] as? Int32) ?? 0
            let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLine, sdpMid: sdpMid)
            if let pc = peer, pc.remoteDescription != nil {
                pc.add(candidate) { _ in }
            } else {
                pendingIce.append(candidate)
            }
            #endif

        default:
            break
        }
    }

    // MARK: - Private

    private func sendSignal(type: String, extras: [String: Any] = [:], to overrideTo: String? = nil, callId overrideCallId: String? = nil) {
        guard let info = info else { return }
        var frame: [String: Any] = [
            "type": type,
            "to": overrideTo ?? info.remoteAlias,
            "call_id": overrideCallId ?? info.callId,
            "crypto_v": 1,
        ]
        for (k, v) in extras { frame[k] = v }
        // TODO: iOS SDK 加 sendSignalFrame(frame:)
        // client.sendSignalFrame(frame)
    }

    #if canImport(WebRTC)
    private func setupPeer(iceServerList: [RTCIceServer]) {
        let config = RTCConfiguration()
        config.iceServers = iceServerList
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peer = Self.factory.peerConnection(with: config, constraints: constraints, delegate: PeerDelegate(manager: self))
    }

    private func attachLocalMedia(mode: CallMode) {
        guard let pc = peer else { return }
        // Audio
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = Self.factory.audioSource(with: audioConstraints)
        let audio = Self.factory.audioTrack(with: audioSource, trackId: "audio0")
        pc.add(audio, streamIds: ["stream0"])
        localAudioTrack = audio

        if mode == .video {
            let videoSource = Self.factory.videoSource()
            let capturer = RTCCameraVideoCapturer(delegate: videoSource)
            let video = Self.factory.videoTrack(with: videoSource, trackId: "video0")
            pc.add(video, streamIds: ["stream0"])
            localVideoTrack = video
            videoCapturer = capturer
            startCapturer(capturer: capturer)
        }
    }

    private func startCapturer(capturer: RTCCameraVideoCapturer) {
        let devices = RTCCameraVideoCapturer.captureDevices()
        guard let frontCamera = devices.first(where: { $0.position == .front }) ?? devices.first,
              let format = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
                .sorted(by: { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width >
                             CMVideoFormatDescriptionGetDimensions($1.formatDescription).width })
                .first,
              let fps = format.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate })
        else { return }
        capturer.startCapture(with: frontCamera, format: format, fps: Int(fps.maxFrameRate))
    }

    private func createOfferAndSend(mode: CallMode) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": mode == .video ? "true" : "false"],
            optionalConstraints: nil
        )
        peer?.offer(for: constraints) { [weak self] sdp, _ in
            guard let self, let sdp else { return }
            self.peer?.setLocalDescription(sdp) { _ in }
            self.sendSignal(type: "call_offer", extras: [
                "sdp": sdp.sdp,
                "sdp_type": "offer",
                "mode": mode.rawValue,
            ])
        }
    }

    private func createAnswerAndSend() {
        // 显式指定 OfferToReceiveVideo，确保视频来电被叫方协商出视频 track
        let isVideo = info?.mode == .video
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": isVideo ? "true" : "false",
            ],
            optionalConstraints: nil
        )
        peer?.answer(for: constraints) { [weak self] sdp, _ in
            guard let self, let sdp else { return }
            self.peer?.setLocalDescription(sdp) { _ in }
            self.sendSignal(type: "call_answer", extras: [
                "sdp": sdp.sdp,
                "sdp_type": "answer",
            ])
            self.flushPendingIce()
        }
    }

    fileprivate func onRemoteTrack(_ track: RTCMediaStreamTrack) {
        if let audio = track as? RTCAudioTrack { remoteAudioTrack = audio }
        if let video = track as? RTCVideoTrack { remoteVideoTrack = video }
    }

    fileprivate func onIceCandidate(_ candidate: RTCIceCandidate) {
        sendSignal(type: "call_ice", extras: [
            "candidate": candidate.sdp,
            "sdp_mid": candidate.sdpMid ?? "",
            "sdp_mline": Int(candidate.sdpMLineIndex),
        ])
    }

    private func flushPendingIce() {
        guard let pc = peer else { return }
        for c in pendingIce { pc.add(c) { _ in } }
        pendingIce.removeAll()
    }
    #endif

    private func teardown() {
        #if canImport(WebRTC)
        try? videoCapturer?.stopCapture()
        videoCapturer = nil
        peer?.close()
        peer = nil
        localAudioTrack = nil
        localVideoTrack = nil
        remoteAudioTrack = nil
        remoteVideoTrack = nil
        pendingIce.removeAll()
        #endif
        micMuted = false
        cameraMuted = false
    }
}

#if canImport(WebRTC)
private final class PeerDelegate: NSObject, RTCPeerConnectionDelegate {
    weak var manager: CallManager?
    init(manager: CallManager) { self.manager = manager }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        manager?.onIceCandidate(candidate)
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        manager?.onRemoteTrack(rtpReceiver.track!)
    }
    // 其它必需但可忽略的 delegate callbacks
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        if newState == .failed || newState == .closed {
            Task { @MainActor in self.manager?.hangup() }
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
#endif

// MARK: - CallScreenView (SwiftUI)
//
// P2-2 · 对齐 PWA CallScreen.tsx / Android CallScreen.kt
// 放在 CallManager.swift 内, 避免新增 .swift 文件需手工 Add to Target
//
// 调用方式: 在 MainView / ContentView 根据 callManager.state ≠ .idle 显示为浮层
//   if callManager.state != .idle {
//     CallScreenView(callManager: callManager)
//   }

import SwiftUI

struct CallScreenView: View {
    @Bindable var callManager: CallManager

    private var remoteAlias: String {
        callManager.info?.remoteAlias ?? "未知联系人"
    }

    private var isVideo: Bool {
        callManager.info?.mode == .video
    }

    private var stateLabel: String {
        switch callManager.state {
        case .idle:       return ""
        case .outgoing:   return "正在呼叫…"
        case .incoming:   return "来电呼入"
        case .connecting: return "正在建立加密通道…"
        case .connected:  return "通话中"
        case .ended:      return "通话已结束"
        }
    }

    @State private var durationSec: Int = 0

    var body: some View {
        ZStack {
            // 背景 · 连接后全屏远端视频 (视频模式), 音频模式用纯色背景
            DarkBg.ignoresSafeArea()

            // TODO: 视频模式接通后, 此处绘制 remoteVideoTrackForRender (需 UIViewRepresentable 包裹 RTCMTLVideoView)

            VStack {
                // 顶部 · 对方信息
                VStack(spacing: Spacing.s3) {
                    Avatar(text: remoteAlias, size: .lg)

                    Text(remoteAlias)
                        .font(.system(size: TextSize.xl, weight: .semibold))
                        .foregroundColor(TextPrimary)

                    if callManager.state == .connected {
                        Text(formatDuration(durationSec))
                            .font(.system(size: TextSize.sm, design: .monospaced))
                            .foregroundColor(SuccessText)

                        Text("🔒 端到端加密通话")
                            .font(.system(size: TextSize.xs))
                            .padding(.horizontal, Spacing.s2)
                            .padding(.vertical, 4)
                            .overlay(
                                Capsule().stroke(SuccessText.opacity(0.4), lineWidth: 1)
                            )
                            .foregroundColor(SuccessText)
                    } else {
                        Text(stateLabel)
                            .font(.system(size: TextSize.sm))
                            .foregroundColor(BrandPrimaryText)
                    }
                }
                .padding(.top, 80)

                Spacer()

                // 底部控制栏
                HStack(spacing: Spacing.s6) {
                    if callManager.state == .incoming {
                        // 来电: 拒绝 + 接听
                        Button(action: { callManager.reject() }) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(DangerColor))
                        }

                        Button(action: { callManager.answer() }) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(SuccessColor))
                        }
                    } else {
                        // 通话中: 静音 + 挂断 + 摄像头(仅视频)
                        Button(action: { callManager.toggleMic() }) {
                            Image(systemName: callManager.micMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(callManager.micMuted ? DangerColor.opacity(0.8) : Surface2))
                        }

                        Button(action: { callManager.hangup() }) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(Circle().fill(DangerColor))
                        }

                        if isVideo {
                            Button(action: { callManager.toggleCamera() }) {
                                Image(systemName: callManager.cameraMuted ? "video.slash.fill" : "video.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(callManager.cameraMuted ? DangerColor.opacity(0.8) : Surface2))
                            }
                        }
                    }
                }
                .padding(.bottom, 64)
            }
        }
        .onChange(of: callManager.state) { _, newState in
            if newState == .connected {
                durationSec = 0
            }
        }
        .task(id: callManager.state) {
            guard callManager.state == .connected else { return }
            while !Task.isCancelled && callManager.state == .connected {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                durationSec += 1
            }
        }
    }

    private func formatDuration(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }
}
