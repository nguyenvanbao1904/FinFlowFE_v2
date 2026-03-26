import FinFlowCore

public actor PortfolioRepository: PortfolioRepositoryProtocol {
    private let client: any HTTPClientProtocol

    public init(client: any HTTPClientProtocol) {
        self.client = client
    }

    public func getPortfolios() async throws -> [PortfolioResponse] {
        try await client.request(
            endpoint: "/investments/portfolios",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func createPortfolio(request: CreatePortfolioRequest) async throws -> PortfolioResponse {
        try await client.request(
            endpoint: "/investments/portfolios",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }
}

