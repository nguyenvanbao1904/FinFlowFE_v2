import FinFlowCore
import Foundation

public actor BudgetRepository: BudgetRepositoryProtocol {
    private let client: any HTTPClientProtocol

    public init(client: any HTTPClientProtocol) {
        self.client = client
    }

    public func getBudgets() async throws -> [BudgetResponse] {
        try await client.request(
            endpoint: "/budgets",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func createBudget(request: CreateBudgetRequest) async throws -> BudgetResponse {
        try await client.request(
            endpoint: "/budgets",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func updateBudget(id: String, request: UpdateBudgetRequest) async throws -> BudgetResponse {
        try await client.request(
            endpoint: "/budgets/\(id)",
            method: "PUT",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func deleteBudget(id: String) async throws {
        let _: EmptyResponse = try await client.request(
            endpoint: "/budgets/\(id)",
            method: "DELETE",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }
}
