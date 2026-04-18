//
//  VanityShopView.swift
//  SecureChatTemplate
//
//  Created by Claude on 2026/4/15.
//

import SwiftUI
import SecureChatSDK

/// 靓号商店屏幕 — 实接 SDK：search → purchase → poll → bind
struct VanityShopView: View {
    @State var appState: AppState
    @State private var query = ""
    @State private var results: [VanityItem] = []
    @State private var isSearching = false
    @State private var errorMsg: String? = nil

    @State private var selected: VanityItem? = nil
    @State private var purchaseOrder: PurchaseOrder? = nil
    @State private var orderStatus: String = ""
    @State private var nowDate = Date()

    private let client = SecureChatClient.shared()

    var body: some View {
        VStack(spacing: Spacing20) {
            // 顶栏
            HStack {
                Button(action: {
                    appState.route = .confirmBackup
                }) {
                    HStack(spacing: Spacing8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("返回")
                    }
                    .foregroundColor(TextMuted)
                }
                Spacer()
                Button(action: { appState.route = .setNickname }) {
                    Text("跳过").foregroundColor(TextMuted)
                }
            }
            .padding(.horizontal, Spacing20)
            .padding(.top, Spacing16)

            // 标题
            VStack(alignment: .leading, spacing: Spacing8) {
                Text("选择靓号 (可选)").font(.system(size: 22, weight: .bold)).foregroundColor(TextPrimary)
                Text("购买一个易记的用户名，而不是随机生成的 ID")
                    .font(.system(size: 14)).foregroundColor(TextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing20)

            // 搜索框
            HStack(spacing: Spacing8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(TextMuted)
                TextField("搜索靓号", text: $query)
                    .font(.system(size: 16)).foregroundColor(TextPrimary)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await search() } }
                if !query.isEmpty {
                    Button(action: { query = ""; results = [] }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(TextMuted)
                    }
                }
                Button(action: { Task { await search() } }) {
                    if isSearching {
                        ProgressView().tint(BlueAccent)
                    } else {
                        Text("搜索").foregroundColor(BlueAccent).font(.system(size: 14, weight: .semibold))
                    }
                }
                .disabled(query.isEmpty || isSearching)
            }
            .frame(height: Theme.inputHeight)
            .padding(.horizontal, Spacing12)
            .background(Surface1)
            .cornerRadius(RadiusMedium)
            .padding(.horizontal, Spacing20)

            // 错误提示
            if let err = errorMsg {
                Text(err).font(.system(size: 12)).foregroundColor(DangerColor)
                    .padding(.horizontal, Spacing20)
            }

            // 搜索结果
            ScrollView(.vertical) {
                VStack(spacing: Spacing8) {
                    ForEach(results, id: \.aliasId) { item in
                        VanityRow(item: item, isSelected: item.aliasId == selected?.aliasId) {
                            Task { await purchase(item) }
                        }
                    }
                }
                .padding(.horizontal, Spacing20)
            }

            // 支付与轮询卡片
            if let order = purchaseOrder {
                paymentCard(order: order)
                    .padding(.horizontal, Spacing20)
            }

            Spacer()
        }
        .appBackground()
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            nowDate = Date()
        }
    }

    @ViewBuilder
    private func paymentCard(order: PurchaseOrder) -> some View {
        let exp = ISO8601DateFormatter().date(from: order.expiredAt)
        let remaining = exp.map { Int(max(0, $0.timeIntervalSince(nowDate))) } ?? 0
        let mm = remaining / 60, ss = remaining % 60
        let statusLabel: String = {
            switch orderStatus {
            case "pending":   return "等待支付…"
            case "confirmed": return "已确认，绑定中…"
            case "expired":   return "订单过期"
            case "failed":    return "支付失败"
            default:          return "加载中…"
            }
        }()

        VStack(alignment: .leading, spacing: Spacing8) {
            HStack {
                Text("支付订单").font(.system(size: 14, weight: .bold)).foregroundColor(TextPrimary)
                Spacer()
                Text(String(format: "%d:%02d", mm, ss))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
            }
            Text("支付以认领 @\(order.aliasId)").font(.system(size: 12)).foregroundColor(TextMuted)
            Text(statusLabel)
                .font(.system(size: 12))
                .foregroundColor(orderStatus == "confirmed" ? .green : BlueAccent)
            if let urlStr = order.paymentUrl, let url = URL(string: urlStr) {
                Link(destination: url) {
                    Text("打开支付页").frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .background(BlueAccent).foregroundColor(.white).cornerRadius(RadiusMedium)
            }
        }
        .padding(Spacing12)
        .background(Surface1)
        .cornerRadius(RadiusMedium)
    }

    private func search() async {
        guard !query.isEmpty else { return }
        isSearching = true
        errorMsg = nil
        defer { Task { @MainActor in isSearching = false } }
        do {
            let res = try await client.vanity?.search(query: query) ?? []
            await MainActor.run { results = res }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription }
        }
    }

    private func purchase(_ item: VanityItem) async {
        do {
            guard let order = try await client.vanity?.purchase(aliasId: item.aliasId) else { return }
            await MainActor.run {
                selected = item
                purchaseOrder = order
                orderStatus = "pending"
            }
            // 轮询订单状态
            while true {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let cur = purchaseOrder else { return }
                if let pair = try? await client.vanity?.getOrderStatus(orderId: cur.orderId) {
                    await MainActor.run { orderStatus = pair.status }
                    if pair.status == "confirmed" {
                        try? await client.vanity?.bind(orderId: cur.orderId)
                        await MainActor.run {
                            appState.route = .setNickname
                        }
                        return
                    }
                    if pair.status == "expired" || pair.status == "failed" {
                        return
                    }
                }
            }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription }
        }
    }
}

private struct VanityRow: View {
    let item: VanityItem
    let isSelected: Bool
    let onBuy: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(item.aliasId)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(TextPrimary)
                let label: String = {
                    switch item.tier {
                    case "top":      return "Top"
                    case "premium":  return "Premium"
                    case "standard": return "Standard"
                    default:         return item.tier
                    }
                }()
                let color: Color = {
                    switch item.tier {
                    case "top":     return .orange
                    case "premium": return BlueAccent
                    default:        return TextMuted
                    }
                }()
                Text(item.isFeatured ? "★ \(label)" : label)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }
            Spacer()
            Button(action: onBuy) {
                Text("$\(item.priceUsdt) USDT")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(BlueAccent)
                    .cornerRadius(RadiusSmall)
            }
        }
        .padding(Spacing12)
        .background(isSelected ? BlueAccent.opacity(0.15) : Surface1)
        .cornerRadius(RadiusMedium)
    }
}

#Preview {
    VanityShopView(appState: AppState())
}
