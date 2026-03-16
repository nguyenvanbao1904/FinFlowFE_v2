import Foundation

/// Fetches all wealth accounts for the current user (unified wallet + asset).
public struct GetWealthAccountsUseCase: Sendable {
    private let repository: any WealthAccountRepositoryProtocol

    public init(repository: any WealthAccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [WealthAccountResponse] {
        try await repository.getWealthAccounts()
    }
}
