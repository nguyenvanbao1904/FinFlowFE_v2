import FinFlowCore

public struct GetPortfolioVsMarketUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        portfolioId: String,
        code: String = "VNINDEX"
    ) async throws -> PortfolioMarketBenchmarkResponse {
        try await repository.getPortfolioBenchmark(portfolioId: portfolioId, code: code)
    }
}

