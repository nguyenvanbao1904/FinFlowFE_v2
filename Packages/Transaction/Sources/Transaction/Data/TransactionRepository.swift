import FinFlowCore
import Foundation

public actor TransactionRepository: TransactionRepositoryProtocol {
    private let client: any HTTPClientProtocol

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
        var endpoint = "/transactions?page=\(page)&size=\(size)"

        // Format dates as "yyyy-MM-dd" for backend LocalDate.parse()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current  // Use user's timezone

        if let start = startDate {
            endpoint += "&startDate=\(dateFormatter.string(from: start))"
        }
        if let end = endDate {
            endpoint += "&endDate=\(dateFormatter.string(from: end))"
        }
        if let keyword = keyword, !keyword.trimmingCharacters(in: .whitespaces).isEmpty {
            let encodedKeyword =
                keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
            endpoint += "&keyword=\(encodedKeyword)"
        }

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

    public func getChart(range: ChartRange, referenceDate: Date) async throws
        -> TransactionChartResponse {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let dateStr = fmt.string(from: referenceDate)
        return try await client.request(
            endpoint: "/transactions/chart?range=\(range.rawValue)&referenceDate=\(dateStr)",
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
}
