import FinFlowCore

public struct DeleteCategoryUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: String) async throws {
        try await repository.deleteCategory(id: id)
    }
}
