import Foundation
import FinFlowCore

/// Creates a new budget. Parse va validate amount, format dates truoc khi gui len repository.
public struct CreateBudgetUseCase: Sendable {
    private let repository: any BudgetRepositoryProtocol

    public init(repository: any BudgetRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        categoryId: String,
        targetAmountString: String,
        startDate: Date,
        endDate: Date,
        isRecurring: Bool
    ) async throws -> BudgetResponse {
        let amount = try Self.parseAmount(targetAmountString)
        let startStr = Self.formatDate(startDate)
        let endStr = Self.formatDate(endDate)
        let request = CreateBudgetRequest(
            categoryId: categoryId,
            targetAmount: amount,
            startDate: startStr,
            endDate: endStr,
            isRecurring: isRecurring,
            recurringStartDate: isRecurring ? startStr : nil
        )
        return try await repository.createBudget(request: request)
    }

    // MARK: - Helpers

    /// Parse chuoi amount (dinh dang VN "1.500.000" hoac quoc te "1,500,000") thanh Double.
    /// Throw AppError.validationError neu khong hop le hoac <= 0.
    public static func parseAmount(_ raw: String) throws -> Double {
        guard let value = CurrencyFormatter.parseCurrencyInput(raw), value > 0 else {
            throw AppError.validationError("Số tiền ngân sách không hợp lệ")
        }
        return value
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    /// Format Date thanh "yyyy-MM-dd" string (timezone local, yeu cau cua backend).
    public static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
