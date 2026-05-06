import FinFlowCore

public struct GetMonthlyNetBuyUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(month: String? = nil) async throws -> Double {
        try await repository.getMonthlyNetBuy(month: month)
    }
}
