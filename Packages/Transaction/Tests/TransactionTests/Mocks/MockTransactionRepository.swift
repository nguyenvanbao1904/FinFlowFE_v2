import FinFlowCore
import Foundation

// MARK: - Mock Transaction Repository
// Dùng để inject vào UseCases trong Unit Tests, tránh phụ thuộc network/database.

final class MockTransactionRepository: TransactionRepositoryProtocol, @unchecked Sendable {

    // MARK: - Stub Responses (set trước khi test)

    var stubbedCategories: [CategoryResponse] = []
    var stubbedCategoryResult: CategoryResponse = .mock()
    var stubbedTransactionResult: TransactionResponse = .mock()
    var stubbedPaginatedTransactions: PaginatedResponse<TransactionResponse> = .mockEmpty()
    var stubbedSummary: TransactionSummaryResponse = .mock()
    var stubbedAnalyzeResult: AnalyzeTransactionResponse = .mock()
    var stubbedInsights: TransactionAnalyticsInsightsResponse = .mockEmpty()
    var stubbedChart: TransactionChartResponse = .mockEmpty()

    /// Set để force throw error từ bất kỳ method nào
    var errorToThrow: Error?

    // MARK: - Call Trackers (dùng để verify trong tests)

    var addTransactionCallCount = 0
    var lastAddTransactionRequest: AddTransactionRequest?

    var getTransactionsCallCount = 0
    var lastGetTransactionsPage: Int?
    var lastGetTransactionsSize: Int?
    var lastGetTransactionsStartDate: Date?
    var lastGetTransactionsEndDate: Date?
    var lastGetTransactionsKeyword: String?

    var getTransactionSummaryCallCount = 0
    var getCategoriesCallCount = 0

    // MARK: - TransactionRepositoryProtocol

    func getCategories() async throws -> [CategoryResponse] {
        if let error = errorToThrow { throw error }
        getCategoriesCallCount += 1
        return stubbedCategories
    }

    func createCategory(request: CreateCategoryRequest) async throws -> CategoryResponse {
        if let error = errorToThrow { throw error }
        return stubbedCategoryResult
    }

    func updateCategory(id: String, request: UpdateCategoryRequest) async throws -> CategoryResponse {
        if let error = errorToThrow { throw error }
        return stubbedCategoryResult
    }

    func deleteCategory(id: String) async throws {
        if let error = errorToThrow { throw error }
    }

    func addTransaction(request: AddTransactionRequest) async throws -> TransactionResponse {
        if let error = errorToThrow { throw error }
        addTransactionCallCount += 1
        lastAddTransactionRequest = request
        return stubbedTransactionResult
    }

    func updateTransaction(id: String, request: AddTransactionRequest) async throws -> TransactionResponse {
        if let error = errorToThrow { throw error }
        return stubbedTransactionResult
    }

    func getTransactions(
        page: Int,
        size: Int,
        startDate: Date?,
        endDate: Date?,
        keyword: String?
    ) async throws -> PaginatedResponse<TransactionResponse> {
        if let error = errorToThrow { throw error }
        getTransactionsCallCount += 1
        lastGetTransactionsPage = page
        lastGetTransactionsSize = size
        lastGetTransactionsStartDate = startDate
        lastGetTransactionsEndDate = endDate
        lastGetTransactionsKeyword = keyword
        return stubbedPaginatedTransactions
    }

    func getTransactionSummary() async throws -> TransactionSummaryResponse {
        if let error = errorToThrow { throw error }
        getTransactionSummaryCallCount += 1
        return stubbedSummary
    }

    func analyzeTransaction(request: AnalyzeTransactionRequest) async throws -> AnalyzeTransactionResponse {
        if let error = errorToThrow { throw error }
        return stubbedAnalyzeResult
    }

    func getAnalyticsInsights() async throws -> TransactionAnalyticsInsightsResponse {
        if let error = errorToThrow { throw error }
        return stubbedInsights
    }

    func getChart(range: ChartRange, referenceDate: Date) async throws -> TransactionChartResponse {
        if let error = errorToThrow { throw error }
        return stubbedChart
    }

    func deleteTransaction(id: String) async throws {
        if let error = errorToThrow { throw error }
    }
}

// MARK: - Test Fixtures (factory methods cho test data)

extension CategoryResponse {
    static func mock(
        id: String = "cat-001",
        name: String = "Ăn uống",
        type: TransactionType = .expense,
        icon: String? = "fork.knife",
        color: String = "#FF6B6B",
        systemCategory: Bool = false
    ) -> CategoryResponse {
        CategoryResponse(id: id, name: name, type: type, icon: icon, color: color, systemCategory: systemCategory)
    }
}

extension TransactionResponse {
    static func mock(
        id: String = "txn-001",
        amount: Double = 150_000,
        type: TransactionType = .expense,
        category: CategoryResponse = .mock(),
        note: String? = "Cơm trưa",
        accountId: String = "acc-001",
        transactionDate: String = "2026-04-13T12:00:00",
        createdAt: String = "2026-04-13T12:00:00"
    ) -> TransactionResponse {
        TransactionResponse(
            id: id, amount: amount, type: type, category: category,
            note: note, accountId: accountId,
            transactionDate: transactionDate, createdAt: createdAt
        )
    }
}

extension TransactionSummaryResponse {
    static func mock(
        totalBalance: Double = 500_000,
        totalIncome: Double = 2_000_000,
        totalExpense: Double = 1_500_000
    ) -> TransactionSummaryResponse {
        TransactionSummaryResponse(totalBalance: totalBalance, totalIncome: totalIncome, totalExpense: totalExpense)
    }
}

extension PaginatedResponse where T == TransactionResponse {
    static func mockEmpty() -> PaginatedResponse<TransactionResponse> {
        PaginatedResponse(content: [], totalElements: 0, totalPages: 0, size: 20, number: 0)
    }

    static func mock(items: [TransactionResponse]) -> PaginatedResponse<TransactionResponse> {
        PaginatedResponse(content: items, totalElements: items.count, totalPages: 1, size: 20, number: 0)
    }
}

extension AnalyzeTransactionResponse {
    static func mock() -> AnalyzeTransactionResponse {
        AnalyzeTransactionResponse(
            amount: 50_000, type: .expense,
            suggestedCategoryId: "cat-001", suggestedAccountId: "acc-001",
            note: "Cà phê", transactionDate: nil
        )
    }
}

extension TransactionAnalyticsInsightsResponse {
    static func mockEmpty() -> TransactionAnalyticsInsightsResponse {
        TransactionAnalyticsInsightsResponse(insights: [], cached: false)
    }
}

extension TransactionChartResponse {
    static func mockEmpty() -> TransactionChartResponse {
        TransactionChartResponse(dataPoints: [], periodLabel: "Tháng 4/2026", hasNext: false)
    }
}

// MARK: - Mock Error

enum MockError: Error, Equatable {
    case networkFailure
    case unauthorized
    case serverError(code: Int)
}
