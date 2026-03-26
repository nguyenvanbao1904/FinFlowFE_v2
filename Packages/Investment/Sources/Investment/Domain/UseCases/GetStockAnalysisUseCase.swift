import Foundation

public struct GetStockAnalysisUseCase: Sendable {
    private let repository: any InvestmentRepositoryProtocol

    public init(repository: any InvestmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        symbol: String,
        annualLimit: Int? = nil,
        quarterlyLimit: Int? = nil
    ) async throws -> InvestmentAnalysisBundle {
        try await repository.getAnalysis(
            symbol: symbol,
            annualLimit: annualLimit,
            quarterlyLimit: quarterlyLimit
        )
    }

    public func executeFinancialSeries(
        symbol: String,
        annualLimit: Int? = nil,
        quarterlyLimit: Int? = nil
    ) async throws -> FinancialDataSeries? {
        try await repository.getFinancialSeries(
            symbol: symbol,
            annualLimit: annualLimit,
            quarterlyLimit: quarterlyLimit
        )
    }

    public func executeValuations(
        symbol: String,
        annualLimit: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        showQuarterly: Bool? = nil
    ) async throws -> [ValuationDataPoint] {
        try await repository.getValuations(
            symbol: symbol,
            annualLimit: annualLimit,
            startDate: startDate,
            endDate: endDate,
            showQuarterly: showQuarterly
        )
    }

    public func executeDividends(
        symbol: String,
        annualLimit: Int? = nil
    ) async throws -> [DividendDataPoint] {
        try await repository.getDividends(
            symbol: symbol,
            annualLimit: annualLimit
        )
    }
}
