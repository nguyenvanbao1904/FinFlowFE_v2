import Foundation

public protocol InvestmentRepositoryProtocol: Sendable {
    func getAnalysis(
        symbol: String,
        annualLimit: Int?,
        quarterlyLimit: Int?
    ) async throws -> InvestmentAnalysisBundle

    func getFinancialSeries(
        symbol: String,
        annualLimit: Int?,
        quarterlyLimit: Int?
    ) async throws -> FinancialDataSeries?

    func getValuations(
        symbol: String,
        annualLimit: Int?,
        startDate: Date?,
        endDate: Date?,
        showQuarterly: Bool?
    ) async throws -> [ValuationDataPoint]

    func getDividends(
        symbol: String,
        annualLimit: Int?
    ) async throws -> [DividendDataPoint]
}
