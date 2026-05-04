import FinFlowCore
import Foundation

public struct GetMonthlySummaryUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    /// Lấy summary thu/chi của tháng chỉ định (format "yyyy-MM"), mặc định tháng hiện tại.
    public func execute(month: String? = nil) async throws -> TransactionSummaryResponse {
        try await repository.getMonthlySummary(month: month)
    }

    /// Tháng hiện tại dạng "yyyy-MM".
    public static var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}
