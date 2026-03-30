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
        -> PortfolioMarketBenchmarkResponse
    {
        try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/benchmark?code=\(code)",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getPortfolioPerformance(portfolioId: String, range: String) async throws -> PortfolioPerformanceResponse {
        let encoded = range.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? range
        return try await client.request(
            endpoint: "/investments/portfolios/\(portfolioId)/performance?range=\(encoded)",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }
}

