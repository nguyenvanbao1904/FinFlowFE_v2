import Foundation

/// Fetches portfolio assets snapshot for a given portfolio.
public struct GetPortfolioAssetsUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(portfolioId: String) async throws -> [PortfolioAssetResponse] {
        try await repository.getPortfolioAssets(portfolioId: portfolioId)
    }
}

