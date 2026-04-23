import FinFlowCore

/// Fetches wealth account type options for pickers (includes transactionEligible).
public struct GetWealthAccountTypesUseCase: Sendable {
    private let repository: any WealthAccountRepositoryProtocol

    public init(repository: any WealthAccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [AccountTypeOptionResponse] {
        try await repository.getAccountTypes()
    }
}
