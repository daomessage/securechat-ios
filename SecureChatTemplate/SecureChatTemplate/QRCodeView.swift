//
//  QRCodeView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

/// 我的二维码显示视图
/// - 用 CoreImage 生成 securechat://add?aliasId=xxx 二维码
/// - 显示 aliasId 文本
struct MyQRCodeView: View {
    @Binding var isPresented: Bool
    let aliasId: String
    @State private var qrImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing20) {
                HStack {
                    Text("我的二维码")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TextPrimary)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(TextMuted)
                    }
                }
                .padding(.horizontal, Spacing20)
                .padding(.top, Spacing20)

                VStack(spacing: Spacing20) {
                    Text("扫描此码添加我为好友")
                        .font(.system(size: 14))
                        .foregroundColor(TextMuted)
                        .multilineTextAlignment(.center)

                    // 二维码图片
                    if let qrImage = qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240, height: 240)
                            .padding(Spacing20)
                            .background(Color.white)
                            .cornerRadius(RadiusLarge)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: RadiusLarge)
                                .fill(Surface1)
                            ProgressView()
                                .tint(BlueAccent)
                        }
                        .frame(height: 280)
                    }

                    // aliasId 显示
                    VStack(alignment: .center, spacing: Spacing8) {
                        Text("我的 ID")
                            .font(.system(size: 12))
                            .foregroundColor(TextMuted)
                        Text("@\(aliasId)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(TextPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing12)
                    .background(Surface1)
                    .cornerRadius(RadiusMedium)

                    // 复制按钮
                    Button(action: {
                        UIPasteboard.general.string = aliasId
                    }) {
                        HStack(spacing: Spacing8) {
                            Image(systemName: "doc.on.doc")
                            Text("复制 ID")
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .secondaryButton()
                    .frame(height: Theme.inputHeight)
                }
                .padding(.horizontal, Spacing20)

                Spacer()
            }
            .background(DarkBg)
            .onAppear {
                generateQRCode()
            }
        }
    }

    /// 生成二维码
    private func generateQRCode() {
        let urlString = "securechat://add?aliasId=\(aliasId)"
        guard let data = urlString.data(using: .utf8) else { return }

        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")

        if let ciImage = filter.outputImage {
            // 放大二维码
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = ciImage.transformed(by: transform)

            // 转换为 UIImage
            let context = CIContext()
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrImage = UIImage(cgImage: cgImage)
            }
        }
    }
}

/// 二维码扫描视图 - 用于扫码添加好友
/// 基于 AVCaptureSession + AVCaptureMetadataOutput
/// 调用方在 onScanned 收到 QR 内容文本（含 securechat://add?aliasId= 或纯 alias）
struct QRScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScanned = { text in
            onScanned(text)
            isPresented = false
        }
        vc.onCancel = {
            isPresented = false
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

/// 内部承载 AVCaptureSession 的 UIViewController
final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScanned: ((String) -> Void)?
    var onCancel: (() -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()

        // 取消按钮
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cancelBtn.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelBtn)
        NSLayoutConstraint.activate([
            cancelBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        ])

        // 提示文字
        let hint = UILabel()
        hint.text = "将二维码对准取景框"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 14)
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func handleCancel() {
        onCancel?()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.layer.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        self.previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr,
              let text = obj.stringValue else { return }
        // 防止连续触发
        session.stopRunning()
        onScanned?(text)
    }
}

/// 解析 QR 文本：securechat://add?aliasId=xxx 或纯 alias
func parseAliasFromQR(_ raw: String) -> String? {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefix = "securechat://add?aliasId="
    if t.hasPrefix(prefix) {
        let after = t.dropFirst(prefix.count).split(separator: "&").first.map(String.init) ?? ""
        return after.isEmpty ? nil : after
    }
    let regex = try? NSRegularExpression(pattern: "^[A-Za-z0-9_]{3,30}$")
    if let regex = regex, regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil {
        return t
    }
    return nil
}

#Preview {
    MyQRCodeView(
        isPresented: .constant(true),
        aliasId: "u12345678"
    )
}
