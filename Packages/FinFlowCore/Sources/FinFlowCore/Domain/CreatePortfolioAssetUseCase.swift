import Foundation

/// Creates/updates a portfolio asset snapshot for a given portfolio.
public struct CreatePortfolioAssetUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        portfolioId: String,
        request: CreatePortfolioAssetRequest
    ) async throws -> PortfolioAssetResponse {
        try await repository.createPortfolioAsset(portfolioId: portfolioId, request: request)
    }
}

