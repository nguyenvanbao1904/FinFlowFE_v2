//
//  HomeDashboardSnapshot.swift
//  FinFlowCore
//
//  Display-only snapshot for the home hub (aggregated in the app layer).
//

import Foundation

/// Aggregated figures for the home screen; safe to use from any feature module.
public struct HomeDashboardSnapshot: Sendable, Equatable {
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

/// Thrown when loading the home snapshot exceeds the allowed time window.
public struct HomeDashboardLoadTimeoutError: Error, Sendable {
    public init() {}
}

extension HomeDashboardLoadTimeoutError: LocalizedError {
    public var errorDescription: String? {
        "Hết thời gian chờ khi tải dữ liệu."
    }
}
