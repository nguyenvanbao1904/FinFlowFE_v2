import Foundation
import FinFlowCore

public actor TransactionRepository: TransactionRepositoryProtocol {
    private let client: any HTTPClientProtocol

    private static let queryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public init(client: any HTTPClientProtocol) {
        self.client = client
    }

    public func getCategories() async throws -> [CategoryResponse] {
        return try await client.request(
            endpoint: "/transactions/categories",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func createCategory(request: CreateCategoryRequest) async throws -> CategoryResponse {
        return try await client.request(
            endpoint: "/transactions/categories",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func updateCategory(id: String, request: UpdateCategoryRequest) async throws
        -> CategoryResponse {
        return try await client.request(
            endpoint: "/transactions/categories/\(id)",
            method: "PUT",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func deleteCategory(id: String) async throws {
        let _: EmptyResponse = try await client.request(
            endpoint: "/transactions/categories/\(id)",
            method: "DELETE",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func addTransaction(request: AddTransactionRequest) async throws -> TransactionResponse {
        return try await client.request(
            endpoint: "/transactions",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func getTransactions(
        page: Int, size: Int, startDate: Date?, endDate: Date?, keyword: String?
    ) async throws
        -> PaginatedResponse<TransactionResponse> {
        let endpoint = buildTransactionsEndpoint(
            page: page,
            size: size,
            startDate: startDate,
            endDate: endDate,
            keyword: keyword
        )

        return try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getTransactionSummary() async throws -> TransactionSummaryResponse {
        return try await client.request(
            endpoint: "/transactions/summary",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getMonthlySummary(month: String? = nil) async throws -> TransactionSummaryResponse {
        var endpoint = "/transactions/summary/monthly"
        if let month {
            endpoint += "?month=\(month)"
        }
        return try await client.request(
            endpoint: endpoint,
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func analyzeTransaction(request: AnalyzeTransactionRequest) async throws
        -> AnalyzeTransactionResponse {
        return try await client.request(
            endpoint: "/transactions/analyze",
            method: "POST",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func getAnalyticsInsights() async throws -> TransactionAnalyticsInsightsResponse {
        return try await client.request(
            endpoint: "/transactions/analytics-insights",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func getChart(range: ChartRange, referenceDate: Date) async throws
        -> TransactionChartResponse {
        let dateStr = Self.queryDateFormatter.string(from: referenceDate)
        return try await client.request(
            endpoint: buildChartEndpoint(range: range, referenceDate: dateStr),
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }
    public func updateTransaction(id: String, request: AddTransactionRequest) async throws
        -> TransactionResponse {
        return try await client.request(
            endpoint: "/transactions/\(id)",
            method: "PUT",
            body: request,
            headers: nil,
            version: nil
        )
    }

    public func deleteTransaction(id: String) async throws {
        let _: EmptyResponse = try await client.request(
            endpoint: "/transactions/\(id)",
            method: "DELETE",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    private func buildTransactionsEndpoint(
        page: Int,
        size: Int,
        startDate: Date?,
        endDate: Date?,
        keyword: String?
    ) -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]

        if let startDate {
            queryItems.append(
                URLQueryItem(name: "startDate", value: Self.queryDateFormatter.string(from: startDate)))
        }

        if let endDate {
            queryItems.append(
                URLQueryItem(name: "endDate", value: Self.queryDateFormatter.string(from: endDate)))
        }

        if let keyword {
            let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKeyword.isEmpty {
                queryItems.append(URLQueryItem(name: "keyword", value: trimmedKeyword))
            }
        }

        return buildEndpoint(path: "/transactions", queryItems: queryItems)
    }

    private func buildChartEndpoint(range: ChartRange, referenceDate: String) -> String {
        buildEndpoint(
            path: "/transactions/chart",
            queryItems: [
                URLQueryItem(name: "range", value: range.rawValue),
                URLQueryItem(name: "referenceDate", value: referenceDate)
            ]
        )
    }

    private func buildEndpoint(path: String, queryItems: [URLQueryItem]) -> String {
        guard !queryItems.isEmpty else { return path }

        var components = URLComponents()
        components.path = path
        components.queryItems = queryItems
        return components.string ?? path
    }
}
