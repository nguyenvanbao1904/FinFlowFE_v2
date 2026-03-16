import Foundation

/// Fetches all budgets for the current user.
public struct GetBudgetsUseCase: Sendable {
    private let repository: any BudgetRepositoryProtocol

    public init(repository: any BudgetRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [BudgetResponse] {
        try await repository.getBudgets()
    }
}
