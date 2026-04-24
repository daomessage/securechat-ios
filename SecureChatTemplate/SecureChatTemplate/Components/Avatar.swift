//
//  Avatar.swift
//  SecureChatTemplate
//
//  三端统一头像组件 · 对齐 docs/DESIGN_TOKENS.md · docs/UI_PARITY_REPORT.md P0-3
//

import SwiftUI

/// Avatar 尺寸枚举 · 三端共享尺寸规格
enum AvatarSize: CGFloat {
    case sm = 32        // 列表项
    case md = 48        // 聊天头像 / 顶栏
    case lg = 80        // Welcome / 资料卡
    case xl = 96        // 特殊场景

    /// 字号 · size × 0.4
    var fontSize: CGFloat { rawValue * 0.4 }
}

/// Avatar · gradient 蓝 → 紫背景 + 首字母
struct Avatar: View {
    let text: String
    var size: AvatarSize = .md

    private var letters: String {
        String(text.prefix(2)).uppercased()
    }

    // 品牌 gradient · 对齐 PWA / Android
    // blue-500 → violet-500 → purple-500
    private let gradient = LinearGradient(
        colors: [
            Color(red: 59/255, green: 130/255, blue: 246/255),     // #3B82F6 blue-500
            Color(red: 139/255, green: 92/255, blue: 246/255),     // #8B5CF6 violet-500
            Color(red: 168/255, green: 85/255, blue: 247/255),     // #A855F7 purple-500
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            Circle().fill(gradient)
            Text(letters)
                .font(.system(size: size.fontSize, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size.rawValue, height: size.rawValue)
    }
}

#Preview {
    HStack(spacing: 20) {
        Avatar(text: "AB", size: .sm)
        Avatar(text: "CD", size: .md)
        Avatar(text: "EF", size: .lg)
        Avatar(text: "GH", size: .xl)
    }
    .padding()
    .background(Color.black)
}
