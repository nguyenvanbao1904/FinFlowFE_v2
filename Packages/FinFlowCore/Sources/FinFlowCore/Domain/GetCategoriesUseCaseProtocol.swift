import Foundation

/// Protocol for loading categories (e.g. for budget category picker). Implemented by Transaction.GetCategoriesUseCase.
public protocol GetCategoriesUseCaseProtocol: Sendable {
    func execute() async throws -> [CategoryResponse]
}
