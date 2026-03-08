import Foundation
import FinFlowCore

public struct GetTransactionChartUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol
    
    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(range: ChartRange, referenceDate: Date) async throws -> TransactionChartResponse {
        return try await repository.getChart(range: range, referenceDate: referenceDate)
    }
}
