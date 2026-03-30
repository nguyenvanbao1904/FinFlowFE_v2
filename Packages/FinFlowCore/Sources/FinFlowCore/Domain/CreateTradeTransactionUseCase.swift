import Foundation

/// Creates a new trade transaction (BUY/SELL/DEPOSIT/WITHDRAW) inside an investment portfolio.
public struct CreateTradeTransactionUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(portfolioId: String, request: CreateTradeTransactionRequest) async throws {
        _ = try await repository.createTradeTransaction(portfolioId: portfolioId, request: request)
    }
}

