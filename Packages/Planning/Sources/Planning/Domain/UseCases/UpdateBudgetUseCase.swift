import Foundation
import FinFlowCore

/// Updates an existing budget. Reuse parse/format helpers tu CreateBudgetUseCase.
public struct UpdateBudgetUseCase: Sendable {
    private let repository: any BudgetRepositoryProtocol

    public init(repository: any BudgetRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        id: String,
        categoryId: String,
        targetAmountString: String,
        startDate: Date,
        endDate: Date,
        isRecurring: Bool
    ) async throws -> BudgetResponse {
        let amount = try CreateBudgetUseCase.parseAmount(targetAmountString)
        let startStr = CreateBudgetUseCase.formatDate(startDate)
        let endStr = CreateBudgetUseCase.formatDate(endDate)
        let request = UpdateBudgetRequest(
            categoryId: categoryId,
            targetAmount: amount,
            startDate: startStr,
            endDate: endStr,
            isRecurring: isRecurring,
            recurringStartDate: isRecurring ? startStr : nil
        )
        return try await repository.updateBudget(id: id, request: request)
    }
}
