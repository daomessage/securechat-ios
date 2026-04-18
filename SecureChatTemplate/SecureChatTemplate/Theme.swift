//
//  Theme.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI

// MARK: - Color Palette (Dark mode, Tailwind zinc/blue)

/// 主背景色 - zinc-950
let DarkBg = Color(red: 0.04, green: 0.04, blue: 0.05)

/// 卡片/输入框背景 - zinc-900
let Surface1 = Color(red: 0.09, green: 0.09, blue: 0.11)

/// 边框/分割线 - zinc-800
let Surface2 = Color(red: 0.15, green: 0.15, blue: 0.16)

/// 次要文字颜色 - zinc-500
let TextMuted = Color(red: 0.44, green: 0.44, blue: 0.46)

/// 主色 - blue-500
let BlueAccent = Color(red: 0.24, green: 0.51, blue: 0.96)

/// 危险色 - red-500
let DangerColor = Color(red: 0.94, green: 0.27, blue: 0.27)

/// 成功色 - green-500
let SuccessColor = Color(red: 0.13, green: 0.77, blue: 0.37)

/// 警告色 - amber-400
let WarningColor = Color(red: 0.98, green: 0.75, blue: 0.14)

/// 主文字颜色 - white/zinc-50
let TextPrimary = Color(red: 0.98, green: 0.98, blue: 0.98)

// MARK: - Spacing Constants

let Spacing2 = 2.0
let Spacing4 = 4.0
let Spacing6 = 6.0
let Spacing8 = 8.0
let Spacing10 = 10.0
let Spacing12 = 12.0
let Spacing14 = 14.0
let Spacing16 = 16.0
let Spacing20 = 20.0
let Spacing24 = 24.0
let Spacing32 = 32.0
let Spacing40 = 40.0

// MARK: - Radius Constants

let RadiusSmall = 8.0
let RadiusMedium = 12.0
let RadiusLarge = 16.0
let RadiusXL = 24.0

// MARK: - Theme Configuration

struct Theme {
    static let cornerRadius = RadiusMedium
    static let buttonHeight = 52.0
    static let inputHeight = 44.0

    /// 标准按钮样式
    static func buttonStyle(
        background: Color = BlueAccent,
        foreground: Color = TextPrimary,
        cornerRadius: Double = RadiusMedium
    ) -> some View {
        EmptyView()
    }
}

// MARK: - View Modifiers

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: Theme.buttonHeight)
            .foregroundColor(TextPrimary)
            .background(BlueAccent.opacity(isEnabled ? 1 : 0.5))
            .cornerRadius(RadiusMedium)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: Theme.buttonHeight)
            .foregroundColor(TextPrimary)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusMedium)
                    .stroke(Surface2, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Extension Helpers

extension View {
    func primaryButton() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    func secondaryButton() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }

    /// 添加通用背景和安全区域处理
    func appBackground() -> some View {
        background(DarkBg)
            .ignoresSafeArea(edges: .all)
    }
}
