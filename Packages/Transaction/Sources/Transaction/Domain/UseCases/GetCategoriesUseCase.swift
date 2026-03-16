import Foundation
import FinFlowCore

public struct GetCategoriesUseCase: GetCategoriesUseCaseProtocol, Sendable {
    private let repository: any TransactionRepositoryProtocol
    
    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute() async throws -> [CategoryResponse] {
        return try await repository.getCategories()
    }
}
