import FinFlowCore

public struct CreateCategoryUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    /// Tạo category mới. Trim whitespace và normalize empty strings trước khi gửi lên repository.
    public func execute(
        name: String,
        type: TransactionType,
        icon: String?,
        color: String?
    ) async throws -> CategoryResponse {
        let request = CreateCategoryRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            icon: icon?.isEmpty == true ? nil : icon,
            color: color?.isEmpty == true ? nil : color
        )
        return try await repository.createCategory(request: request)
    }
}
