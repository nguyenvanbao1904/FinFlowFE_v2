import Foundation
import FinFlowCore

public struct UpdateTransactionUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol
    
    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(id: String, request: AddTransactionRequest) async throws
        -> TransactionResponse {
        return try await repository.updateTransaction(id: id, request: request)
    }
}
