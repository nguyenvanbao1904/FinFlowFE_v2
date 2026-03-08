import Foundation
import FinFlowCore

public protocol AnalyzeTextUseCaseProtocol: Sendable {
    func execute(text: String) async throws -> AnalyzeTransactionResponse
}

public struct AnalyzeTextUseCase: AnalyzeTextUseCaseProtocol {
    private let repository: any TransactionRepositoryProtocol
    
    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(text: String) async throws -> AnalyzeTransactionResponse {
        let request = AnalyzeTransactionRequest(text: text)
        return try await repository.analyzeTransaction(request: request)
    }
}
