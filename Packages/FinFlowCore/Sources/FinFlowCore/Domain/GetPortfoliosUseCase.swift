import Foundation

/// Fetches all investment portfolios for the current user.
public struct GetPortfoliosUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [PortfolioResponse] {
        try await repository.getPortfolios()
    }
}
