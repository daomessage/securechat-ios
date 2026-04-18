//
//  NetworkBanner.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI

/// 网络状态横幅组件
/// - disconnected/connecting 时：顶部橙色横幅「重新连接中...」
/// - connected 时：自动消失（动画）
/// - 用 .overlay(alignment: .top) 覆盖在 MainView 上
struct NetworkBanner: View {
    let state: NetworkState

    var body: some View {
        if case .disconnected(let retryCount) = state {
            VStack(spacing: 0) {
                HStack(spacing: Spacing8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                        Text("连接中... (重试 \(retryCount))")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(WarningColor)
            }
            .transition(.move(edge: .top))
        } else if case .connecting = state {
            VStack(spacing: 0) {
                HStack(spacing: Spacing8) {
                    ProgressView()
                        .scaleEffect(0.8, anchor: .center)
                        .tint(.white)

                    Text("连接中...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(WarningColor)
            }
            .transition(.move(edge: .top))
        }
        // connected 时不显示
    }
}

#Preview {
    VStack {
        NetworkBanner(state: .disconnected(retryCount: 2))

        Spacer()

        NetworkBanner(state: .connecting)

        Spacer()

        NetworkBanner(state: .connected)

        Spacer()
    }
    .background(DarkBg)
}
