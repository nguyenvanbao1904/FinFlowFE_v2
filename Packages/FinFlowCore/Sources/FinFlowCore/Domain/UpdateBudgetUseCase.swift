import Foundation

/// Updates an existing budget.
public struct UpdateBudgetUseCase: Sendable {
    private let repository: any BudgetRepositoryProtocol

    public init(repository: any BudgetRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: String, request: UpdateBudgetRequest) async throws -> BudgetResponse {
        try await repository.updateBudget(id: id, request: request)
    }
}
