import FinFlowCore

public struct GetTradeTransactionsUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(portfolioId: String, page: Int = 0, size: Int = 20) async throws
        -> PageResponse<TradeTransactionResponse> {
        try await repository.getTradeTransactions(portfolioId: portfolioId, page: page, size: size)
    }
}
