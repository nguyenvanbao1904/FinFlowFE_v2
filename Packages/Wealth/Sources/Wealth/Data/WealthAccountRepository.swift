import FinFlowCore

public actor WealthAccountRepository: WealthAccountRepositoryProtocol {
    private let client: any HTTPClientProtocol

    public init(client: any HTTPClientProtocol) {
        self.client = client
    }

    public func getAccountTypes() async throws -> [AccountTypeOptionResponse] {
        try await client.request(
            endpoint: "/wealth/accounts/types",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getWealthAccounts() async throws -> [WealthAccountResponse] {
        try await client.request(
            endpoint: "/wealth/accounts",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func createWealthAccount(request: CreateWealthAccountRequest) async throws -> WealthAccountResponse {
        try await client.request(
            endpoint: "/wealth/accounts",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func updateWealthAccount(id: String, request: UpdateWealthAccountRequest) async throws -> WealthAccountResponse {
        try await client.request(
            endpoint: "/wealth/accounts/\(id)",
            method: "PUT",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func deleteWealthAccount(id: String) async throws {
        let _: EmptyResponse = try await client.request(
            endpoint: "/wealth/accounts/\(id)",
            method: "DELETE",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }
}
