import Foundation

/// Deletes a budget.
public struct DeleteBudgetUseCase: Sendable {
    private let repository: any BudgetRepositoryProtocol

    public init(repository: any BudgetRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: String) async throws {
        try await repository.deleteBudget(id: id)
    }
}
