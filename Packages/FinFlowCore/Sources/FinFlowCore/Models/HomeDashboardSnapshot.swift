//
//  HomeDashboardSnapshot.swift
//  FinFlowCore
//
//  Display-only snapshot for the home hub (aggregated in the app layer).
//

import Foundation

/// Aggregated figures for the home screen; safe to use from any feature module.
public struct HomeDashboardSnapshot: Sendable, Equatable {
    public let netWorth: Double
    public let liquidAssets: Double
    public let debtTotal: Double
    public let investmentAssets: Double
    public let totalBalance: Double
    public let totalIncome: Double
    public let totalExpense: Double
    public let budgetTargetTotal: Double
    public let budgetSpentTotal: Double
    public let portfolioCount: Int
    public let portfolioCashTotal: Double
    public let primaryPortfolioName: String?
    /// Tiền mặt + cổ (giá vốn) gộp mọi danh mục — dùng cho hero Trang chủ.
    public let investmentTotalValue: Double

    public init(
        netWorth: Double,
        liquidAssets: Double,
        debtTotal: Double,
        investmentAssets: Double,
        totalBalance: Double,
        totalIncome: Double,
        totalExpense: Double,
        budgetTargetTotal: Double,
        budgetSpentTotal: Double,
        portfolioCount: Int,
        portfolioCashTotal: Double,
        primaryPortfolioName: String?,
        investmentTotalValue: Double
    ) {
        self.netWorth = netWorth
        self.liquidAssets = liquidAssets
        self.debtTotal = debtTotal
        self.investmentAssets = investmentAssets
        self.totalBalance = totalBalance
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.budgetTargetTotal = budgetTargetTotal
        self.budgetSpentTotal = budgetSpentTotal
        self.portfolioCount = portfolioCount
        self.portfolioCashTotal = portfolioCashTotal
        self.primaryPortfolioName = primaryPortfolioName
        self.investmentTotalValue = investmentTotalValue
    }
}

/// Loads a home dashboard snapshot without coupling Dashboard to feature modules.
public protocol HomeDashboardService: Sendable {
    func loadSnapshot() async throws -> HomeDashboardSnapshot
}

/// Short AI narrative shown directly on Home. The Dashboard package only knows this contract;
/// the app layer decides whether the source is LLM, cache, or a deterministic fallback.
public struct HomeInsight: Sendable, Equatable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public protocol HomeInsightService: Sendable {
    func loadInsight(for snapshot: HomeDashboardSnapshot) async throws -> HomeInsight
}

/// Thrown when loading the home snapshot exceeds the allowed time window.
public struct HomeDashboardLoadTimeoutError: Error, Sendable {
    public init() {}
}

extension HomeDashboardLoadTimeoutError: LocalizedError {
    public var errorDescription: String? {
        "Hết thời gian chờ khi tải dữ liệu."
    }
}
