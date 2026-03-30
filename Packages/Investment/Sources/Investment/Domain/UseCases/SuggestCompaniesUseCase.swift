import FinFlowCore
import Foundation

public struct SuggestCompaniesUseCase: Sendable {
    private let repository: any InvestmentRepositoryProtocol

    public init(repository: any InvestmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(query: String, limit: Int? = 10) async throws -> [CompanySuggestionResponse] {
        try await repository.suggestCompanies(query: query, limit: limit)
    }
}

