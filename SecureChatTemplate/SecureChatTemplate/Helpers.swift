//
//  Helpers.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import Foundation
import CryptoKit
import SwiftUI
import UIKit

// MARK: - Mnemonic 生成（示例，实际应使用 SDK）

/// 生成 BIP39 12 词助记词
/// 注：实际应调用 SDK 的 KeyDerivation.newMnemonic()
func generateMnemonic() -> String {
    let wordList = [
        "abandon", "ability", "able", "about", "above", "absent", "absolute", "absorb",
        "abstract", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
        "acoustic", "acquire", "across", "act", "action", "actor", "acts", "actual"
    ]
    return (0..<12).map { _ in wordList.randomElement() ?? "" }.joined(separator: " ")
}

/// 验证助记词格式
func validateMnemonic(_ mnemonic: String) -> Bool {
    let words = mnemonic.trimmingCharacters(in: .whitespaces).split(separator: " ")
    return words.count == 12 && words.allSatisfy { !$0.isEmpty }
}

// MARK: - 安全码生成（示例，实际应使用 SDK）

/// 生成 60 位安全码
func generateSecurityCode() -> String {
    let hex = (0..<60).map { _ in String(format: "%X", Int.random(in: 0..<16)) }.joined()
    return hex.uppercased()
}

// MARK: - Date Formatting

/// 格式化日期为相对时间字符串
func formatRelativeTime(_ date: Date) -> String {
    let elapsed = Date().timeIntervalSince(date)

    if elapsed < 60 {
        return "刚刚"
    } else if elapsed < 3600 {
        return "\(Int(elapsed / 60))分钟前"
    } else if elapsed < 86400 {
        return "\(Int(elapsed / 3600))小时前"
    } else if elapsed < 604800 {
        return "\(Int(elapsed / 86400))天前"
    } else {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Validation Helpers

/// 验证昵称有效性
func isValidNickname(_ name: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    return !trimmed.isEmpty && trimmed.count <= 20
}

/// 验证 aliasId 有效性
func isValidAliasId(_ aliasId: String) -> Bool {
    // aliasId 格式: u + 8 位数字，或自定义靓号
    let pattern = "^[u][0-9]{8}$|^[a-z0-9]{3,20}$"
    let regex = try? NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: aliasId.utf16.count)
    return regex?.firstMatch(in: aliasId, range: range) != nil
}

// MARK: - QR Code Generation

import CoreImage

/// 生成 QR 码图像
func generateQRCode(from string: String) -> UIImage? {
    let data = string.data(using: String.Encoding.utf8)
    if let filter = CIFilter(name: "CIQRCodeGenerator") {
        filter.setValue(data, forKey: "inputMessage")
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        if let output = filter.outputImage?.transformed(by: transform) {
            return UIImage(ciImage: output)
        }
    }
    return nil
}

// MARK: - Color Helpers

extension Color {
    /// 从 hex 字符串初始化颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  // RGB
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RRGGBB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // AARRGGBB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extension for Safe Area

extension View {
    /// 返回在 NavigationStack 中应显示的任何 View
    func navigationAppearance() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
