// ============================================================================
// WatchSubscriptionGate.swift
// watchOS 订阅门槛视图（手表端适配，无 sheet 只能用 inline 方式）
// ============================================================================

import SwiftUI
import Shared

/// watchOS 订阅门槛包装器
/// 由于手表不支持 sheet，用 inline 警告 + 按钮代替
struct WatchSubscriptionGated<Destination: View>: View {
    let title: String
    let icon: String
    let destination: () -> Destination

    @ObservedObject private var quotaManager = QuotaManager.shared

    var body: some View {
        if quotaManager.isSubscribed {
            NavigationLink(destination: destination()) {
                Label(title, systemImage: icon)
            }
        } else {
            Button {
                quotaManager.activateSubscription()
            } label: {
                HStack {
                    Label(title, systemImage: icon)
                    Spacer()
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
    }
}

/// watchOS 模型倍率显示（手表端适配）
struct WatchModelPriceBadge: View {
    let modelName: String

    private var multiplier: Double {
        ModelPriceMultiplier.multiplier(for: modelName)
    }

    private var badgeColor: Color {
        if multiplier <= 1.0  { return .green }
        if multiplier <= 1.5  { return .blue }
        if multiplier <= 2.0  { return .orange }
        if multiplier <= 2.5  { return .pink }
        return .purple
    }

    var body: some View {
        Text(ModelPriceMultiplier.displayString(for: modelName))
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(badgeColor, in: Capsule())
    }
}

/// watchOS 配额进度条（手表端简化版）
struct WatchQuotaProgressBar: View {
    let record: QuotaRecord

    private var fillColor: Color {
        if record.usagePercent < 0.5 { return .green }
        if record.usagePercent < 0.8 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("配额")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(record.usagePercentString)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(fillColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geo.size.width * record.usagePercent)
                        .animation(.easeInOut(duration: 0.3), value: record.usagePercent)
                }
            }
            .frame(height: 5)
        }
    }
}
