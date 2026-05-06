import Foundation

/// Reusable use case for fetching AI-powered fair value.
/// Used by DynamicMoSCard (Stock Analysis tab) and anywhere else fair value is needed.
public struct GetFairValueUseCase: Sendable {
    private let repository: any InvestmentRepositoryProtocol

    public init(repository: any InvestmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(symbol: String, targetYear: Int? = nil) async throws -> FairValueResult {
        try await repository.getFairValue(symbol: symbol, targetYear: targetYear)
    }
}
