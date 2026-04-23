import Foundation
import FinFlowCore

public struct UpdateTransactionUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    /// Cập nhật giao dịch theo id. Parse và validate amount, format date trước khi gửi lên repository.
    public func execute(
        id: String,
        amount: String,
        type: TransactionType,
        categoryId: String,
        accountId: String,
        note: String?,
        date: Date
    ) async throws -> TransactionResponse {
        let numericAmount = try AddTransactionUseCase.parseAmount(amount)
        let dateString = AddTransactionUseCase.formatDate(date)
        let request = AddTransactionRequest(
            amount: numericAmount,
            type: type,
            categoryId: categoryId,
            accountId: accountId,
            note: note?.isEmpty == true ? nil : note,
            transactionDate: dateString
        )
        return try await repository.updateTransaction(id: id, request: request)
    }
}
