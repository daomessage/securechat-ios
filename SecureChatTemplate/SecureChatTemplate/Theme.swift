//
//  Theme.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI

// DAO Message 三端统一视觉规范 — 对应 docs/DESIGN_TOKENS.md
// 修改前请先同步 DESIGN_TOKENS.md

// MARK: - Color · 基础背景

/// color.bg.base zinc-950
let DarkBg = Color(red: 9/255, green: 9/255, blue: 11/255)

/// color.bg.surface zinc-900
let Surface1 = Color(red: 24/255, green: 24/255, blue: 27/255)

/// color.bg.surface-raised zinc-800
let Surface2 = Color(red: 39/255, green: 39/255, blue: 42/255)

/// color.bg.hover zinc-700
let SurfaceHover = Color(red: 63/255, green: 63/255, blue: 70/255)

// MARK: - Color · 边框

/// color.border.default zinc-800
let BorderDefault = Color(red: 39/255, green: 39/255, blue: 42/255)

/// color.border.strong zinc-600
let BorderStrong = Color(red: 82/255, green: 82/255, blue: 91/255)

// MARK: - Color · 文字

/// color.text.primary zinc-50
let TextPrimary = Color(red: 250/255, green: 250/255, blue: 250/255)

/// color.text.secondary zinc-300
let TextSecondary = Color(red: 212/255, green: 212/255, blue: 216/255)

/// color.text.muted zinc-400
let TextMutedLight = Color(red: 161/255, green: 161/255, blue: 170/255)

/// color.text.disabled zinc-500
let TextMuted = Color(red: 113/255, green: 113/255, blue: 122/255)

// MARK: - Color · 品牌

/// color.brand.primary blue-500
let BrandPrimary = Color(red: 59/255, green: 130/255, blue: 246/255)

/// color.brand.primary-hover blue-600
let BrandPrimaryHover = Color(red: 37/255, green: 99/255, blue: 235/255)

/// color.brand.primary-text blue-400 (链接 / 辅助)
let BrandPrimaryText = Color(red: 96/255, green: 165/255, blue: 250/255)

/// 别名保留兼容旧代码, 新代码请用 BrandPrimary
let BlueAccent = BrandPrimary

// MARK: - Color · 状态

/// color.status.danger red-500
let DangerColor = Color(red: 239/255, green: 68/255, blue: 68/255)

/// color.status.success green-500
let SuccessColor = Color(red: 34/255, green: 197/255, blue: 94/255)

/// color.status.success-text green-400 (E2EE 徽章)
let SuccessText = Color(red: 74/255, green: 222/255, blue: 128/255)

/// color.status.warning amber-400
let WarningColor = Color(red: 251/255, green: 191/255, blue: 36/255)

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

// MARK: - Radius 命名空间 (对齐 design tokens)

enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
    static let xl: CGFloat = 12
    static let xxl: CGFloat = 16
    static let xxxl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - 字号

enum TextSize {
    static let xs: CGFloat = 12
    static let sm: CGFloat = 14    // 默认正文
    static let base: CGFloat = 16
    static let lg: CGFloat = 18
    static let xl: CGFloat = 20
    static let xl2: CGFloat = 24
    static let xl3: CGFloat = 30
    static let xl4: CGFloat = 36
}

// MARK: - Theme Configuration

struct Theme {
    static let cornerRadius = RadiusMedium
    static let buttonHeight = 48.0      // 对齐 design tokens h.button = 48
    static let inputHeight = 48.0       // 同上 · input 也统一 48

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

// Primary / Secondary / Danger Button · 对齐 docs/DESIGN_TOKENS.md
//   h=48, radius.lg=8, bg=BrandPrimary #3B82F6
//   字号 16 / 字重 medium (比原 semibold 轻一档, 和 Android/PWA 一致)

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: TextSize.base, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: Theme.buttonHeight)
            .foregroundColor(TextPrimary)
            .background(BrandPrimary.opacity(isEnabled ? 1 : 0.5))
            .cornerRadius(Radius.lg)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: TextSize.base, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: Theme.buttonHeight)
            .foregroundColor(TextPrimary)
            .background(Surface2)
            .cornerRadius(Radius.lg)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: TextSize.base, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: Theme.buttonHeight)
            .foregroundColor(TextPrimary)
            .background(DangerColor)
            .cornerRadius(Radius.lg)
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

    func dangerButton() -> some View {
        buttonStyle(DangerButtonStyle())
    }

    /// 添加通用背景和安全区域处理
    func appBackground() -> some View {
        background(DarkBg)
            .ignoresSafeArea(edges: .all)
    }
}
