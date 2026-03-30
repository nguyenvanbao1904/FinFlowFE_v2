//
//  HomeDashboardServiceImpl.swift
//  FinFlowIos
//

import FinFlowCore
import Foundation
import Investment
import Transaction

/// Aggregates transaction summary, budgets, and portfolios into `HomeDashboardSnapshot`.
struct HomeDashboardServiceImpl: HomeDashboardService {
    private let getTransactionSummary: GetTransactionSummaryUseCase
    private let getBudgets: GetBudgetsUseCase
    private let getPortfolios: GetPortfoliosUseCase
    private let getPortfolioAssets: GetPortfolioAssetsUseCase
    private let getPortfolioHealth: GetPortfolioHealthUseCase

    init(
        getTransactionSummary: GetTransactionSummaryUseCase,
        getBudgets: GetBudgetsUseCase,
        getPortfolios: GetPortfoliosUseCase,
        getPortfolioAssets: GetPortfolioAssetsUseCase,
        getPortfolioHealth: GetPortfolioHealthUseCase
    ) {
        self.getTransactionSummary = getTransactionSummary
        self.getBudgets = getBudgets
        self.getPortfolios = getPortfolios
        self.getPortfolioAssets = getPortfolioAssets
        self.getPortfolioHealth = getPortfolioHealth
    }

    func loadSnapshot() async throws -> HomeDashboardSnapshot {
        async let summary = try getTransactionSummary.execute()
        async let budgets = try getBudgets.execute()
        async let portfolios = try getPortfolios.execute()

        let s = try await summary
        let b = try await budgets
        let p = try await portfolios

        let targetTotal = b.reduce(0.0) { $0 + $1.targetAmount }
        let spentTotal = b.reduce(0.0) { $0 + ($1.spentAmount ?? 0) }
        let cashTotal = p.reduce(0.0) { $0 + $1.cashBalance }
        let marketSnapshot = await computeMarketSnapshot(portfolios: p)

        return HomeDashboardSnapshot(
            totalBalance: s.totalBalance,
            totalIncome: s.totalIncome,
            totalExpense: s.totalExpense,
            budgetTargetTotal: targetTotal,
            budgetSpentTotal: spentTotal,
            portfolioCount: p.count,
            portfolioCashTotal: cashTotal,
            primaryPortfolioName: marketSnapshot.primaryPortfolioName,
            investmentTotalValue: marketSnapshot.totalValue
        )
    }

    /// Home dùng giá trị hiện tại (market close) nếu có; fallback sang cash + giá vốn khi health lỗi.
    private func computeMarketSnapshot(portfolios: [PortfolioResponse]) async -> (
        totalValue: Double, primaryPortfolioName: String?
    ) {
        guard !portfolios.isEmpty else { return (0, nil) }

        let getAssets = getPortfolioAssets
        let getHealth = getPortfolioHealth
        var totalValue: Double = 0
        var primaryPortfolioName: String?
        var primaryPortfolioValue = Double.leastNonzeroMagnitude

        await withTaskGroup(of: (name: String, value: Double).self) { group in
            for portfolio in portfolios {
                group.addTask {
                    do {
                        let health = try await getHealth.execute(portfolioId: portfolio.id, quarters: 1)
                        return (name: portfolio.name, value: health.current.totalValueClose)
                    } catch {
                        do {
                            let rows = try await getAssets.execute(portfolioId: portfolio.id)
                            let stock = rows.reduce(0.0) { $0 + ($1.totalQuantity * $1.averagePrice) }
                            return (name: portfolio.name, value: portfolio.cashBalance + stock)
                        } catch {
                            return (name: portfolio.name, value: portfolio.cashBalance)
                        }
                    }
                }
            }

            for await result in group {
                totalValue += result.value
                if result.value > primaryPortfolioValue {
                    primaryPortfolioValue = result.value
                    primaryPortfolioName = result.name
                }
            }
        }

        return (totalValue, primaryPortfolioName)
    }
}
