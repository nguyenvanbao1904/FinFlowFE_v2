import Foundation
import FinFlowCore

public struct GetTransactionsUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        page: Int,
        size: Int = 20,
        startDate: Date? = nil,
        endDate: Date? = nil,
        keyword: String? = nil
    ) async throws -> PaginatedResponse<TransactionResponse> {
        return try await repository.getTransactions(
            page: page,
            size: size,
            startDate: startDate,
            endDate: endDate,
            keyword: keyword
        )
    }
}
