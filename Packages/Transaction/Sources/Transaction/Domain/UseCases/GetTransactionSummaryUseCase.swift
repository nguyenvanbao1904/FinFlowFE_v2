import FinFlowCore

public struct GetTransactionSummaryUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol
    
    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute() async throws -> TransactionSummaryResponse {
        return try await repository.getTransactionSummary()
    }
}
