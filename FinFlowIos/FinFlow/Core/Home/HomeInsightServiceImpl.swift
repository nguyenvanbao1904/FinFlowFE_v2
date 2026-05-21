//
//  HomeInsightServiceImpl.swift
//  FinFlow
//

import FinFlowCore
import Foundation

struct HomeInsightServiceImpl: HomeInsightService {
    private let client: any HTTPClientProtocol

    init(client: any HTTPClientProtocol) {
        self.client = client
    }

    func loadInsight(for snapshot: HomeDashboardSnapshot) async throws -> HomeInsight {
        let response: HomeInsightResponseDTO = try await client.request(
            endpoint: "/dashboard/home-insight",
            method: "POST",
            body: HomeInsightRequestDTO(snapshot: snapshot),
            headers: nil,
            version: nil,
            retryOn401: true,
            extendedTimeout: true
        )

        return HomeInsight(
            title: response.title,
            message: response.message
        )
    }
}

nonisolated private struct HomeInsightRequestDTO: Encodable, Sendable {
    let locale: String = "vi-VN"
    let timezone: String = "Asia/Ho_Chi_Minh"
    let currency: String = "VND"
    let netWorth: Double
    let liquidAssets: Double
    let debtTotal: Double
    let investmentAssets: Double
    let totalBalance: Double
    let totalIncome: Double
    let totalExpense: Double
    let budgetTargetTotal: Double
    let budgetSpentTotal: Double
    let portfolioCount: Int
    let portfolioCashTotal: Double
    let primaryPortfolioName: String?
    let investmentTotalValue: Double

    init(snapshot: HomeDashboardSnapshot) {
        self.netWorth = snapshot.netWorth
        self.liquidAssets = snapshot.liquidAssets
        self.debtTotal = snapshot.debtTotal
        self.investmentAssets = snapshot.investmentAssets
        self.totalBalance = snapshot.totalBalance
        self.totalIncome = snapshot.totalIncome
        self.totalExpense = snapshot.totalExpense
        self.budgetTargetTotal = snapshot.budgetTargetTotal
        self.budgetSpentTotal = snapshot.budgetSpentTotal
        self.portfolioCount = snapshot.portfolioCount
        self.portfolioCashTotal = snapshot.portfolioCashTotal
        self.primaryPortfolioName = snapshot.primaryPortfolioName
        self.investmentTotalValue = snapshot.investmentTotalValue
    }
}

nonisolated private struct HomeInsightResponseDTO: Codable, Sendable {
    let title: String
    let message: String
    let warnings: [String]
    let cached: Bool
}
