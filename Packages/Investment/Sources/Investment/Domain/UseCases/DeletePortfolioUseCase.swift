import FinFlowCore

public struct DeletePortfolioUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    @discardableResult
    public func execute(portfolioId: String) async throws -> EmptyResponse {
        try await repository.deletePortfolio(portfolioId: portfolioId)
    }
}
