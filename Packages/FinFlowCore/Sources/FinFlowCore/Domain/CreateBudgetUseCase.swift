import Foundation

/// Creates a new budget.
public struct CreateBudgetUseCase: Sendable {
    private let repository: any BudgetRepositoryProtocol

    public init(repository: any BudgetRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(request: CreateBudgetRequest) async throws -> BudgetResponse {
        try await repository.createBudget(request: request)
    }
}
