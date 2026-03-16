import Foundation

/// Deletes a wealth account.
public struct DeleteWealthAccountUseCase: Sendable {
    private let repository: any WealthAccountRepositoryProtocol

    public init(repository: any WealthAccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: String) async throws {
        try await repository.deleteWealthAccount(id: id)
    }
}
