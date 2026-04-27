// ============================================================================
// SubscriptionGate.swift
// 订阅门槛视图：未订阅用户显示"订阅后解锁"提示
// ============================================================================

import SwiftUI
import Shared

/// 未订阅用户点击时的提示视图
struct SubscriptionGateView: View {
    let title: String
    let description: String

    @ObservedObject private var quotaManager = QuotaManager.shared
    @State private var showSubscriptionBanner = false

    var body: some View {
        VStack(spacing: 0) {
            if !quotaManager.isSubscribed {
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)

                    Text("订阅后解锁")
                        .font(.system(size: 17, weight: .semibold))

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button {
                        quotaManager.activateSubscription()
                    } label: {
                        Text("免费试用（测试）")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 32)

                    Text("10元/月 · 50万token额度 · 不同模型倍率计费")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)

                    Text(title)
                        .font(.system(size: 17, weight: .semibold))

                    Text("已解锁所有高级功能")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(title)
    }
}

/// 给 NavigationLink 加订阅门槛的包装器
struct SubscriptionGatedLink<Destination: View>: View {
    let title: String
    let icon: String
    let requiresSubscription: Bool
    let destination: () -> Destination

    @ObservedObject private var quotaManager = QuotaManager.shared
    @State private var showGate = false

    var body: some View {
        if requiresSubscription && !quotaManager.isSubscribed {
            Button {
                showGate = true
            } label: {
                HStack {
                    Label(title, systemImage: icon)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                }
            }
            .sheet(isPresented: $showGate) {
                NavigationStack {
                    SubscriptionGateView(
                        title: title,
                        description: "此功能为订阅用户专享。订阅后可解锁自定义提供商、高级模型设置、拓展功能等。"
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭") { showGate = false }
                        }
                    }
                }
            }
        } else {
            NavigationLink {
                destination()
            } label: {
                Label(title, systemImage: icon)
            }
        }
    }
}
