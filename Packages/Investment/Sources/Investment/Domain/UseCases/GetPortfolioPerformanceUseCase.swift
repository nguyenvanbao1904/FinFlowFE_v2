import FinFlowCore
import Foundation

public struct GetPortfolioPerformanceUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(portfolioId: String, range: String = "1Y") async throws -> PortfolioPerformanceResponse {
        try await repository.getPortfolioPerformance(portfolioId: portfolioId, range: range)
    }
}
