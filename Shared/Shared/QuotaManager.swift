// ============================================================================
// QuotaManager.swift
// ETOS LLM Studio 配额管理
//
// 套餐定价（可配置）:
//   - 10元/月固定套餐，固定token额度
//   - 不同模型倍率不同，消耗配额不同
// ============================================================================

import Foundation

// MARK: - 定价配置

public enum QuotaConfig {
    /// 每月套餐价格（元）
    public static let monthlyPrice: Double = 10.0

    /// 每月基础额度（token总数，按 totalTokens 计）
    public static let monthlyTokenQuota: Int = 500_000

    /// 配额刷新日期（每月几号）
    public static let refreshDayOfMonth: Int = 1

    /// 免费用户基础额度（未订阅时）
    public static let freeTokenQuota: Int = 0
}

// MARK: - 模型倍率表

public enum ModelPriceMultiplier {
    /// 根据模型名匹配倍率（越强/越贵的模型倍率越高）
    public static func multiplier(for modelName: String) -> Double {
        let lower = modelName.lowercased()

        // MiniMax 系列 — 1x
        if lower.contains("minimax") || lower.contains("mmmini") {
            return 1.0
        }

        // 硅基流动/DeepSeek — 1.2x
        if lower.contains("deepseek") || lower.contains("silicon") {
            return 1.2
        }

        // Qwen — 1.5x
        if lower.contains("qwen") || lower.contains("tongyi") {
            return 1.5
        }

        // Claude 3.5/3 — 2.5x
        if lower.contains("claude") {
            return 2.5
        }

        // GPT-4o / GPT-4 Turbo — 3x
        if lower.contains("gpt-4o") || lower.contains("gpt-4-turbo") {
            return 3.0
        }

        // GPT-4 — 2x
        if lower.contains("gpt-4") || lower.contains("chatgpt-4") {
            return 2.0
        }

        // GPT-3.5 / GPT-3 — 1x
        if lower.contains("gpt-3.5") || lower.contains("gpt-3") || lower.contains("chatgpt-3") {
            return 1.0
        }

        // Gemini — 1.8x
        if lower.contains("gemini") || lower.contains("google") {
            return 1.8
        }

        // GLM / 智谱 — 1.2x
        if lower.contains("glm") || lower.contains("zhipu") {
            return 1.2
        }

        // 其他/未知 — 1.5x
        return 1.5
    }

    /// 格式化显示倍率
    public static func displayString(for modelName: String) -> String {
        let m = multiplier(for: modelName)
        if m == 1.0 { return "1×" }
        return String(format: "%.1f×", m)
    }
}

// MARK: - 配额记录

public struct QuotaRecord: Codable, Sendable {
    public var usedTokens: Int           // 已消耗 token 总数（折算后）
    public var monthlyTokenQuota: Int     // 当月总配额
    public var subscriptionStartDate: Date? // 订阅开始日期
    public var lastResetDate: Date       // 上次重置日期

    public init(
        usedTokens: Int = 0,
        monthlyTokenQuota: Int = QuotaConfig.monthlyTokenQuota,
        subscriptionStartDate: Date? = nil,
        lastResetDate: Date = Date()
    ) {
        self.usedTokens = usedTokens
        self.monthlyTokenQuota = monthlyTokenQuota
        self.subscriptionStartDate = subscriptionStartDate
        self.lastResetDate = lastResetDate
    }

    public var remainingTokens: Int {
        max(0, monthlyTokenQuota - usedTokens)
    }

    public var usagePercent: Double {
        guard monthlyTokenQuota > 0 else { return 0 }
        return min(1.0, Double(usedTokens) / Double(monthlyTokenQuota))
    }

    public var usagePercentString: String {
        String(format: "%.1f%%", usagePercent * 100)
    }

    public var isExpired: Bool {
        !Calendar.current.isDate(lastResetDate, equalTo: Date(), toGranularity: .month)
    }

    /// 纯消耗（不重置），每次请求后调用
    public mutating func consume(tokens: Int, modelName: String) {
        let multiplier = ModelPriceMultiplier.multiplier(for: modelName)
        let cost = Int(Double(tokens) * multiplier)
        usedTokens += cost
    }

    /// 重置（新月）
    public mutating func resetIfNeeded() {
        if isExpired {
            usedTokens = 0
            lastResetDate = Date()
        }
    }

    /// 是否已用完
    public var isExhausted: Bool {
        remainingTokens <= 0
    }
}

// MARK: - 配额管理器

@MainActor
public final class QuotaManager: ObservableObject {
    public static let shared = QuotaManager()

    @Published public private(set) var record: QuotaRecord
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isSubscribed: Bool = false

    private let storageKey = "etos_quota_record"
    private let subscriptionKey = "etos_subscription_active"

    private init() {
        // 读取已保存的配额记录
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(QuotaRecord.self, from: data) {
            self.record = saved
            // 检查是否需要新月重置
            self.record.resetIfNeeded()
        } else {
            self.record = QuotaRecord()
        }

        // 检查订阅状态
        self.isSubscribed = UserDefaults.standard.bool(forKey: subscriptionKey)

        // 每次启动检查是否需要重置
        checkAndResetIfNeeded()
    }

    // MARK: - 消耗配额

    /// 消耗 token（每次请求后调用）
    /// - Parameters:
    ///   - tokenCount: 原始 token 数量（totalTokens）
    ///   - modelName: 模型名（用于计算倍率）
    public func consume(tokens: Int, modelName: String) {
        record.consume(tokens: tokens, modelName: modelName)
        save()
    }

    // MARK: - 订阅管理（模拟，未接入 StoreKit）

    /// 激活订阅（测试用：永久激活）
    public func activateSubscription() {
        isSubscribed = true
        record.subscriptionStartDate = Date()
        record.monthlyTokenQuota = QuotaConfig.monthlyTokenQuota
        UserDefaults.standard.set(true, forKey: subscriptionKey)
        save()
    }

    /// 取消订阅（测试用）
    public func deactivateSubscription() {
        isSubscribed = false
        record.monthlyTokenQuota = QuotaConfig.freeTokenQuota
        UserDefaults.standard.set(false, forKey: subscriptionKey)
        save()
    }

    // MARK: - 重置

    /// 检查是否需要新月重置
    public func checkAndResetIfNeeded() {
        if record.isExpired {
            record.resetIfNeeded()
            save()
        }
    }

    // MARK: - 私有

    private func save() {
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - 用量查询

    /// 获取最近7天用量摘要
    public func recentUsage() -> Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let logs = Persistence.loadRequestLogs(query: RequestLogQuery(from: sevenDaysAgo, limit: 1000))
        var total: Int = 0
        for entry in logs {
            if let usage = entry.tokenUsage, let totalTokens = usage.totalTokens {
                total += totalTokens
            }
        }
        return total
    }
}
