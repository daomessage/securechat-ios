//
//  VoiceRecorder.swift
//  SecureChatTemplate
//
//  封装 AVAudioRecorder，录 m4a 语音。对标 PWA/Android 的 MediaRecorder。
//

import Foundation
import AVFoundation

/// 语音录制状态
enum VoiceRecorderState {
    case idle
    case recording
    case finished(data: Data, durationMs: Int)
    case error(String)
}

@Observable
final class VoiceRecorder: NSObject, AVAudioRecorderDelegate {

    var state: VoiceRecorderState = .idle
    var elapsedSeconds: Int = 0

    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private var startDate: Date?
    private var timer: Timer?

    /// 请求麦克风权限
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    /// 开始录制
    func start() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            state = .error("无法激活音频会话：\(error.localizedDescription)")
            return false
        }

        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970 * 1000)).m4a")
        outputURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 128_000,
        ]

        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.delegate = self
            r.prepareToRecord()
            r.record()
            recorder = r
            startDate = Date()
            elapsedSeconds = 0
            state = .recording
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.startDate else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
            return true
        } catch {
            state = .error("无法开始录音：\(error.localizedDescription)")
            return false
        }
    }

    /// 停止录制
    /// - save: true 保留并返回数据；false 删除文件
    func stop(save: Bool) {
        timer?.invalidate()
        timer = nil
        guard let r = recorder else { state = .idle; return }
        let durationMs = Int((Date().timeIntervalSince(startDate ?? Date())) * 1000)
        r.stop()
        recorder = nil

        let url = outputURL
        outputURL = nil
        startDate = nil
        elapsedSeconds = 0

        if !save || durationMs < 1000 {
            if let u = url { try? FileManager.default.removeItem(at: u) }
            state = .idle
            return
        }

        guard let u = url, let data = try? Data(contentsOf: u) else {
            state = .error("无法读取录音文件")
            return
        }
        try? FileManager.default.removeItem(at: u)
        state = .finished(data: data, durationMs: durationMs)
    }

    /// 取消
    func cancel() {
        stop(save: false)
    }
}
