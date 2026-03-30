import Foundation

/// Imports/overwrites a portfolio snapshot: cashBalance + holdings.
public struct ImportPortfolioSnapshotUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(portfolioId: String, request: ImportPortfolioSnapshotRequest) async throws {
        _ = try await repository.importPortfolioSnapshot(portfolioId: portfolioId, request: request)
    }
}

