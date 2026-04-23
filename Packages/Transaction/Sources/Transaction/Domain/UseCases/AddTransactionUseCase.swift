import Foundation
import FinFlowCore

public struct AddTransactionUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    /// Thêm giao dịch mới. Parse và validate amount, format date trước khi gửi lên repository.
    public func execute(
        amount: String,
        type: TransactionType,
        categoryId: String,
        accountId: String,
        note: String?,
        date: Date
    ) async throws -> TransactionResponse {
        let numericAmount = try Self.parseAmount(amount)
        let dateString = Self.formatDate(date)
        let request = AddTransactionRequest(
            amount: numericAmount,
            type: type,
            categoryId: categoryId,
            accountId: accountId,
            note: note?.isEmpty == true ? nil : note,
            transactionDate: dateString
        )
        return try await repository.addTransaction(request: request)
    }

    // MARK: - Helpers

    /// Parse chuỗi amount (định dạng VN "1.500.000" hoặc quốc tế "1,500,000") thành Double.
    /// Throw AppError.validationError nếu không hợp lệ hoặc <= 0.
    static func parseAmount(_ raw: String) throws -> Double {
        guard let value = CurrencyFormatter.parseCurrencyInput(raw), value > 0 else {
            throw AppError.validationError("Số tiền không hợp lệ")
        }
        return value
    }

    /// Format Date thành ISO8601 string với fractional seconds (yêu cầu của backend).
    static func formatDate(_ date: Date) -> String {
        date.formatted(
            Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        )
    }
}
