import FinFlowCore
import Foundation

public struct GetTransactionAnalyticsInsightsUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> TransactionAnalyticsInsightsResponse {
        try await repository.getAnalyticsInsights()
    }
}

