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

    public func updatePortfolio(portfolioId: String, request: UpdatePortfolioRequest) async throws -> PortfolioResponse {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)",
            method: "PUT",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func deletePortfolio(portfolioId: String) async throws -> EmptyResponse {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)",
            method: "DELETE",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getPortfolioAssets(portfolioId: String) async throws -> [PortfolioAssetResponse] {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/assets",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func createPortfolioAsset(
        portfolioId: String,
        request: CreatePortfolioAssetRequest
    ) async throws -> PortfolioAssetResponse {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/assets",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func createTradeTransaction(
        portfolioId: String,
        request: CreateTradeTransactionRequest
    ) async throws -> EmptyResponse {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/transactions",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func importPortfolioSnapshot(
        portfolioId: String,
        request: ImportPortfolioSnapshotRequest
    ) async throws -> EmptyResponse {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/import-snapshot",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func getPortfolioHealth(portfolioId: String, quarters: Int = 12) async throws -> PortfolioHealthResponse {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/health?quarters=\(quarters)",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getPortfolioBenchmark(portfolioId: String, code: String = "VNINDEX") async throws
        -> PortfolioMarketBenchmarkResponse {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/benchmark?code=\(code)",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getTradeTransactions(
        portfolioId: String,
        page: Int,
        size: Int
    ) async throws -> PageResponse<TradeTransactionResponse> {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/transactions?page=\(page)&size=\(size)",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getMonthlyNetBuy(month: String? = nil) async throws -> Double {
        var endpoint = "/investments/portfolios/monthly-net-buy"
        if let month { endpoint += "?month=\(month)" }
        let response: [String: Double] = try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
        return response["monthlyNetBuy"] ?? 0
    }

}
