import Foundation
import FinFlowCore

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

    func getDailyValuations(symbol: String, startDate: Date, endDate: Date) async throws -> [DailyValuationDataPoint]

    func getDividends(
        symbol: String,
        annualLimit: Int?
    ) async throws -> [DividendDataPoint]

    func suggestCompanies(
        query: String,
        limit: Int?
    ) async throws -> [CompanySuggestionResponse]

    func getCompanyIndustries(
        symbols: [String]
    ) async throws -> [CompanyIndustryResponse]

    func getFairValue(
        symbol: String,
        targetYear: Int?
    ) async throws -> FairValueResult
}
