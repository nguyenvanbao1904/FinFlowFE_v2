import Foundation
import FinFlowCore

public struct AddTransactionUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol
    
    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(request: AddTransactionRequest) async throws -> TransactionResponse {
        return try await repository.addTransaction(request: request)
    }
}
