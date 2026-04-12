import FinFlowCore
import Foundation
import Observation

@MainActor
@Observable
public class TransactionListViewModel {
    // UI State
    public var transactions: [TransactionResponse] = []
    public var summary: TransactionSummaryResponse?
    public var chartData: TransactionChartResponse?
    public var aiInsights: [AnalyticsInsightResponse] = []
    public var chartRange: ChartRange = .month
    public var chartReferenceDate: Date = Date()
    public var isLoading: Bool = true
    public var isChartLoading: Bool = true
    public var hasHistoryLoadError: Bool = false
    public var hasChartLoadError: Bool = false
    public var isAnalyticsInsightsLoading: Bool = false
    public var alert: AppErrorAlert?
    public var currentPage: Int = 0
    public var hasMorePages: Bool = true

    // Date Range Filter
    public var filterStartDate: Date?
    public var filterEndDate: Date?
    public var showFilterSheet: Bool = false

    // Search
    public var searchText: String = "" {
        didSet {
            searchTask?.cancel()
            searchTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await fetchData(isInitial: true, triggeredBySearch: true, refreshSummaryAndChart: false)
            }
        }
    }
    private var searchTask: Task<Void, Never>?

    // Dependencies
    private let getTransactionsUseCase: GetTransactionsUseCase
    private let getSummaryUseCase: GetTransactionSummaryUseCase
    private let getChartUseCase: GetTransactionChartUseCase
    private let getAnalyticsInsightsUseCase: GetTransactionAnalyticsInsightsUseCase
    private let deleteTransactionUseCase: DeleteTransactionUseCase
    private let router: any AppRouterProtocol
    private let sessionManager: any SessionManagerProtocol
    @ObservationIgnored
    private var hasRequestedInitialLoad = false
    @ObservationIgnored
    private var analyticsInsightsUpToDate = false
    @ObservationIgnored
    private var analyticsSummaryAndChartUpToDate = false
    @ObservationIgnored
    private var latestChartRequestID = UUID()
    public init(
        getTransactionsUseCase: GetTransactionsUseCase,
        getSummaryUseCase: GetTransactionSummaryUseCase,
        getChartUseCase: GetTransactionChartUseCase,
        getAnalyticsInsightsUseCase: GetTransactionAnalyticsInsightsUseCase,
        deleteTransactionUseCase: DeleteTransactionUseCase,
        router: any AppRouterProtocol,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getTransactionsUseCase = getTransactionsUseCase
        self.getSummaryUseCase = getSummaryUseCase
        self.getChartUseCase = getChartUseCase
        self.getAnalyticsInsightsUseCase = getAnalyticsInsightsUseCase
        self.deleteTransactionUseCase = deleteTransactionUseCase
        self.router = router
        self.sessionManager = sessionManager
    }

    public func fetchInitialDataIfNeeded() async {
        guard !hasRequestedInitialLoad else { return }
        hasRequestedInitialLoad = true
        await fetchData(isInitial: true, refreshSummaryAndChart: true)
    }

    public func markAnalyticsInsightsStale() {
        analyticsInsightsUpToDate = false
        analyticsSummaryAndChartUpToDate = false
    }

    public func refreshAfterTransactionMutation() async {
        markAnalyticsInsightsStale()
        await fetchData(isInitial: true, refreshSummaryAndChart: true)
    }

    public func loadAnalyticsSummaryAndChartIfNeeded() async {
        guard !analyticsSummaryAndChartUpToDate else { return }
        do {
            summary = try await getSummaryUseCase.execute()
        } catch {
            // Summary is optional for analytics view; keep existing value.
        }
        await fetchChartData()
        // Only mark up-to-date when chart actually loaded.
        analyticsSummaryAndChartUpToDate = (hasChartLoadError == false)
    }

    public func loadAnalyticsTabDataIfNeeded() async {
        await loadAnalyticsSummaryAndChartIfNeeded()
        await loadAnalyticsInsightsIfNeeded()
    }

    /// Call when user switches to the "Thống kê" segment.
    public func loadAnalyticsInsightsIfNeeded() async {
        guard !isAnalyticsInsightsLoading else { return }
        guard !analyticsInsightsUpToDate else { return }
        isAnalyticsInsightsLoading = true
        defer { isAnalyticsInsightsLoading = false }
        do {
            let insightsResponse = try await getAnalyticsInsightsUseCase.execute()
            aiInsights = insightsResponse.insights
            analyticsInsightsUpToDate = true
        } catch {
            aiInsights = Self.localFallbackInsights
            analyticsInsightsUpToDate = true
        }
    }

    public func fetchData(
        isInitial: Bool = true,
        triggeredBySearch: Bool = false,
        refreshSummaryAndChart: Bool = false
    ) async {
        if isInitial {
            // Only show loading skeleton if not triggered by search (avoid jitter)
            if !triggeredBySearch {
                isLoading = true
            }
            currentPage = 0
            transactions.removeAll()
        }

        defer {
            if !triggeredBySearch {
                isLoading = false
            }
        }

        do {
            if isInitial && refreshSummaryAndChart {
                summary = try await getSummaryUseCase.execute()
            }

            // Fetch paginated transactions with date range filter and search keyword
            let response = try await getTransactionsUseCase.execute(
                page: currentPage,
                size: 20,
                startDate: filterStartDate,
                endDate: filterEndDate,
                keyword: searchText.isEmpty ? nil : searchText
            )
            transactions.append(contentsOf: response.content)
            hasMorePages = response.number < response.totalPages - 1
            hasHistoryLoadError = false

        } catch {
            // Ignore cancellation (from debounce) - don't show error alert
            if error is CancellationError {
                return
            }
            handleError(error)
        }
    }

    // MARK: - Date Range Filter

    public func applyFilter() {
        Task {
            await fetchData(isInitial: true, refreshSummaryAndChart: false)
        }
    }

    public func clearFilter() {
        filterStartDate = nil
        filterEndDate = nil
        Task {
            await fetchData(isInitial: true, refreshSummaryAndChart: false)
        }
    }

    public func fetchChartData() async {
        let requestID = UUID()
        latestChartRequestID = requestID
        isChartLoading = true
        defer {
            if latestChartRequestID == requestID {
                isChartLoading = false
            }
        }

        do {
            let response = try await getChartUseCase.execute(
                range: chartRange, referenceDate: chartReferenceDate)

            guard latestChartRequestID == requestID else { return }
            chartData = response
            hasChartLoadError = false
        } catch {
            guard latestChartRequestID == requestID else { return }
            // Ignore cancellation - don't show error alert
            if error is CancellationError {
                return
            }
            handleError(error, isChartError: true)
        }
    }

    public func updateChartRange(_ newRange: ChartRange) {
        chartRange = newRange
        chartReferenceDate = Date()  // Reset to today when changing range
        isChartLoading = true
        Task {
            await fetchChartData()
        }
    }

    public func navigateChartBack() {
        guard !isChartLoading else { return }
        shiftChartReference(by: -1)
    }

    public func navigateChartForward() {
        guard !isChartLoading else { return }
        guard chartData?.hasNext == true else { return }
        shiftChartReference(by: 1)
    }

    private func handleError(_ error: Error, isChartError: Bool = false) {
        let handled = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Tải Dữ Liệu")
        if handled?.isUnauthorized == true {
            isLoading = false
            isChartLoading = false
            hasHistoryLoadError = false
            hasChartLoadError = false
        } else if isChartError {
            hasChartLoadError = true
        } else {
            hasHistoryLoadError = true
        }
        if let handled {
            self.alert = handled
        }
    }

    public func loadMoreIfNeeded(currentItem: TransactionResponse) async {
        guard let lastItem = transactions.last, currentItem.id == lastItem.id, hasMorePages,
            !isLoading
        else {
            return
        }
        currentPage += 1
        await fetchData(isInitial: false)
    }

    public func presentAddTransaction() {
        router.presentSheet(.addTransaction)
    }

    public func presentCategoryList() {
        router.navigate(to: .categoryList)
    }

    public func deleteTransaction(id: String) async {
        do {
            try await deleteTransactionUseCase.execute(id: id)

            // Remove from local array
            transactions.removeAll { $0.id == id }

            // Refresh history & summary; mark analytics stale.
            // Chart/AI will refresh when user opens the Thống kê segment.
            await refreshAfterTransactionMutation()
            // Giống lưu/sửa giao dịch: các tab khác (ví dụ Kế hoạch) lắng nghe để refetch ngân sách / spent.
            NotificationCenter.default.post(name: .transactionDidSave, object: nil)
        } catch {
            handleError(error)
        }
    }

    public func presentEditTransaction(_ transaction: TransactionResponse) {
        router.presentSheet(.editTransaction(transaction))
    }

    public func generateDetailedReport() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/yyyy"
        let currentMonth = dateFormatter.string(from: Date())
        let prompt = "Hãy tạo cho tôi một báo cáo phân tích chi tiết về tình hình thu chi, biến động các danh mục và gợi ý ngân sách cho tháng \(currentMonth)."
        router.presentSheet(.finFlowBotChat(initialPrompt: prompt))
    }

    // MARK: - Computed Summary

    /// Display summary: when filter is active, calculate from filtered transactions
    /// Otherwise use API summary (all transactions)
    public var displaySummary: TransactionSummaryResponse? {
        // If no filter active, use API summary
        guard filterStartDate != nil || filterEndDate != nil else {
            return summary
        }

        // Calculate from filtered transactions
        guard !transactions.isEmpty else {
            return TransactionSummaryResponse(
                totalBalance: 0,
                totalIncome: 0,
                totalExpense: 0
            )
        }

        let income =
            transactions
            .filter { $0.type == .income }
            .reduce(0.0) { $0 + $1.amount }

        let expense =
            transactions
            .filter { $0.type == .expense }
            .reduce(0.0) { $0 + $1.amount }

        let balance = income - expense

        return TransactionSummaryResponse(
            totalBalance: balance,
            totalIncome: income,
            totalExpense: expense
        )
    }

    // MARK: - Grouped Transactions

    /// Groups transactions by date with proper timezone conversion (UTC -> GMT+7)
    /// Returns array of (title: String, items: [TransactionResponse])
    public var groupedTransactions: [(title: String, items: [TransactionResponse])] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Group by date
        let grouped = Dictionary(grouping: transactions) { transaction -> Date in
            guard
                let date = TransactionDateParser.parseBackendLocalDateTime(
                    transaction.transactionDate)
            else {
                return Date(timeIntervalSince1970: 0)
            }
            return calendar.startOfDay(for: date)
        }

        // Sort by date descending and format labels
        return
            grouped
            .sorted { $0.key > $1.key }
            .map { (date, items) in
                let title: String
                if calendar.isDate(date, inSameDayAs: today) {
                    title = "Hôm nay"
                } else if calendar.isDate(date, inSameDayAs: yesterday) {
                    title = "Hôm qua"
                } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                    // Same week: "Thứ Ba, 04/03"
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "EEEE, dd/MM"
                    dayFormatter.locale = Locale(identifier: "vi_VN")
                    title = dayFormatter.string(from: date).capitalized
                } else {
                    // Different week/year: "05/02/2026"
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "dd/MM/yyyy"
                    title = dayFormatter.string(from: date)
                }
                return (
                    title: title, items: items.sorted { $0.transactionDate > $1.transactionDate }
                )
            }
    }

    private func shiftChartReference(by step: Int) {
        var components = DateComponents()
        switch chartRange {
        case .week:
            components.day = 7 * step
        case .month:
            components.month = 1 * step
        case .quarter:
            components.month = 3 * step
        case .year:
            components.year = 1 * step
        }

        if let newDate = Calendar.current.date(byAdding: components, to: chartReferenceDate) {
            guard
                Calendar.current.compare(newDate, to: chartReferenceDate, toGranularity: .day)
                    != .orderedSame
            else {
                return
            }
            chartReferenceDate = newDate
            isChartLoading = true
            Task {
                await fetchChartData()
            }
        }
    }

    private static let localFallbackInsights: [AnalyticsInsightResponse] = [
        AnalyticsInsightResponse(
            id: "local-fallback-warning",
            type: .warning,
            title: "Theo dõi chi tiêu",
            message: "Không thể tải phân tích AI lúc này. Hãy theo dõi các khoản chi lớn trong kỳ.",
            confidence: 0.5
        ),
        AnalyticsInsightResponse(
            id: "local-fallback-tip",
            type: .tip,
            title: "Mẹo tài chính",
            message: "Duy trì ghi nhận giao dịch đều đặn để hệ thống đưa ra gợi ý chính xác hơn.",
            confidence: 0.5
        ),
    ]
}
