//
//  CallKitProvider.swift
//  SecureChatTemplate
//
//  iOS CallKit 集成 — 让来电可在锁屏/后台弹出系统来电 UI
//
//  ⚠️ 需要在 Xcode 里启用 Signing & Capabilities → Background Modes → "Voice over IP"
//  完整生产使用需接 PushKit (VoIP Push) 让后台推送可唤起 reportNewIncomingCall
//

import Foundation
import CallKit
import AVFoundation

final class CallKitProvider: NSObject, CXProviderDelegate {

    static let shared = CallKitProvider()

    private let provider: CXProvider
    private let callController = CXCallController()

    override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = true
        self.provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    /// 对端来电 — 调用 reportNewIncomingCall 让系统弹出 CallKit UI
    func reportIncomingCall(uuid: UUID, from alias: String, hasVideo: Bool) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: alias)
        update.hasVideo = hasVideo
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("CallKit reportIncomingCall failed: \(error)")
            }
        }
    }

    /// 用户发起呼出 — 向 CallController 请求 StartCallAction
    func startOutgoingCall(uuid: UUID, to alias: String, hasVideo: Bool) {
        let handle = CXHandle(type: .generic, value: alias)
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = hasVideo
        callController.request(CXTransaction(action: action)) { error in
            if let error = error { print("CallKit startOutgoing failed: \(error)") }
        }
    }

    func endCall(uuid: UUID) {
        let action = CXEndCallAction(call: uuid)
        callController.request(CXTransaction(action: action)) { error in
            if let error = error { print("CallKit endCall failed: \(error)") }
        }
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in CallManager.shared.hangup() }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in CallManager.shared.answer() }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in CallManager.shared.hangup() }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Task { @MainActor in
            if action.isMuted != CallManager.shared.micMuted {
                CallManager.shared.toggleMic()
            }
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // 通话被 CallKit 激活音频会话时通知 WebRTC audio unit
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}
}
