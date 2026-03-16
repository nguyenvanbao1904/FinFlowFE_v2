import Foundation

/// Creates a new wealth account.
public struct CreateWealthAccountUseCase: Sendable {
    private let repository: any WealthAccountRepositoryProtocol

    public init(repository: any WealthAccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(request: CreateWealthAccountRequest) async throws -> WealthAccountResponse {
        try await repository.createWealthAccount(request: request)
    }
}
