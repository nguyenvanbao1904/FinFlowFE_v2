import Foundation

/// Updates an existing wealth account.
public struct UpdateWealthAccountUseCase: Sendable {
    private let repository: any WealthAccountRepositoryProtocol

    public init(repository: any WealthAccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: String, request: UpdateWealthAccountRequest) async throws -> WealthAccountResponse {
        try await repository.updateWealthAccount(id: id, request: request)
    }
}
