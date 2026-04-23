import FinFlowCore

/// Updates an existing wealth account. Reuse parse/sign logic tu CreateWealthAccountUseCase.
public struct UpdateWealthAccountUseCase: Sendable {
    private let repository: any WealthAccountRepositoryProtocol

    public init(repository: any WealthAccountRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        id: String,
        name: String,
        amountString: String,
        accountType: AccountTypeOptionResponse,
        includeInNetWorth: Bool
    ) async throws -> WealthAccountResponse {
        let balance = try CreateWealthAccountUseCase.resolveBalance(
            amountString: amountString,
            isDebt: accountType.debt
        )
        let request = UpdateWealthAccountRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            accountTypeId: accountType.id,
            balance: balance,
            includeInNetWorth: includeInNetWorth
        )
        return try await repository.updateWealthAccount(id: id, request: request)
    }
}
