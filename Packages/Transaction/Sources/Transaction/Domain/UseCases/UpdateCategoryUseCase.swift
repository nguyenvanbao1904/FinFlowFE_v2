import FinFlowCore

public struct UpdateCategoryUseCase: Sendable {
    private let repository: any TransactionRepositoryProtocol

    public init(repository: any TransactionRepositoryProtocol) {
        self.repository = repository
    }

    /// Cập nhật category. Trim whitespace và normalize empty strings trước khi gửi lên repository.
    public func execute(
        id: String,
        name: String,
        icon: String?,
        color: String?
    ) async throws -> CategoryResponse {
        let request = UpdateCategoryRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon?.isEmpty == true ? nil : icon,
            color: color?.isEmpty == true ? nil : color
        )
        return try await repository.updateCategory(id: id, request: request)
    }
}
