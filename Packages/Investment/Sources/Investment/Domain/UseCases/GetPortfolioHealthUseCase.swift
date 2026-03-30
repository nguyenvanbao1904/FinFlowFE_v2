import FinFlowCore

public struct GetPortfolioHealthUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(portfolioId: String, quarters: Int = 12) async throws -> PortfolioHealthResponse {
        try await repository.getPortfolioHealth(portfolioId: portfolioId, quarters: quarters)
    }
}
