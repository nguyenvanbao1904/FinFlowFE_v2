import FinFlowCore

/// Creates a new empty investment portfolio (cashBalance=0).
public struct CreatePortfolioUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(request: CreatePortfolioRequest) async throws -> PortfolioResponse {
        try await repository.createPortfolio(request: request)
    }
}
