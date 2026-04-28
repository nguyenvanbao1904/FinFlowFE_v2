import FinFlowCore

public struct UpdatePortfolioUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(portfolioId: String, request: UpdatePortfolioRequest) async throws -> PortfolioResponse {
        try await repository.updatePortfolio(portfolioId: portfolioId, request: request)
    }
}
