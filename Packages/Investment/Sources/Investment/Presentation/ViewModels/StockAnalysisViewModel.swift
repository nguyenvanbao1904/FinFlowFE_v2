import Foundation
import FinFlowCore

@MainActor
@Observable
public final class StockAnalysisViewModel {
    public var overview: StockOverview?
    public var shareholders: [ShareholderDataPoint] = []
    public var valuations: [ValuationDataPoint] = []
    public var financials: FinancialDataSeries?
    public var dividends: [DividendDataPoint] = []

    public var isLoading = false
    public var error: AppErrorAlert?
    public var isLoadingFullHistory = false

    private let getStockAnalysisUseCase: GetStockAnalysisUseCase
    private let sessionManager: any SessionManagerProtocol
    private var currentSymbol: String = "ACB"
    private var didLoadFullFinancials = false
    private var didLoadFullValuations = false
    private var didLoadFullDividends = false
    private var valuationsRangeRequestId: Int = 0

    public init(
        getStockAnalysisUseCase: GetStockAnalysisUseCase,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getStockAnalysisUseCase = getStockAnalysisUseCase
        self.sessionManager = sessionManager
    }

    public func load(symbol: String = "ACB") async {
        currentSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        didLoadFullFinancials = false
        didLoadFullValuations = false
        didLoadFullDividends = false
        isLoading = true
        defer { isLoading = false }

        do {
            // Snapshot tab: giới hạn để payload nhẹ; backend dùng LIMIT ở SQL. Full history: loadFull*IfNeeded.
            let result = try await getStockAnalysisUseCase.execute(
                symbol: currentSymbol,
                annualLimit: 4,
                quarterlyLimit: 4
            )
            overview = result.overview
            shareholders = result.shareholders
            valuations = result.valuations
            financials = result.financials
            dividends = result.dividends
            error = nil
        } catch {
            // Giống các tab khác: bỏ qua khi Task bị huỷ (chuyển tab nhanh).
            if error is CancellationError {
                return
            }
            // Refresh thất bại hoặc API trả 401 có thể là `.unauthorized` hoặc `serverError(1010, …)` — dùng httpStatusCode.
            if let appError = error as? AppError, appError.httpStatusCode == 401 {
                self.error = .authWithAction(
                    message: AppErrorAlert.sessionExpiredMessage
                ) { [sessionManager] in
                    Task { @MainActor in
                        await sessionManager.clearExpiredSession()
                    }
                }
                return
            }
            self.error = error.toAppAlert(defaultTitle: "Lỗi Tải Dữ Liệu")
        }
    }

    public func loadFullFinancialsIfNeeded() async {
        guard !didLoadFullFinancials, !isLoadingFullHistory, !currentSymbol.isEmpty else { return }
        isLoadingFullHistory = true
        defer { isLoadingFullHistory = false }

        do {
            let fullFinancials = try await getStockAnalysisUseCase.executeFinancialSeries(symbol: currentSymbol)
            financials = fullFinancials
            didLoadFullFinancials = true
            error = nil
        } catch {
            if error is CancellationError {
                return
            }
            self.error = error.toAppAlert(defaultTitle: "Lỗi Tải Dữ Liệu Tài Chính")
        }
    }

    public func loadFullValuationsIfNeeded() async {
        guard !didLoadFullValuations, !isLoadingFullHistory, !currentSymbol.isEmpty else { return }
        isLoadingFullHistory = true
        defer { isLoadingFullHistory = false }

        do {
            valuations = try await getStockAnalysisUseCase.executeValuations(symbol: currentSymbol)
            didLoadFullValuations = true
            error = nil
        } catch {
            if error is CancellationError {
                return
            }
            self.error = error.toAppAlert(defaultTitle: "Lỗi Tải Dữ Liệu Định Giá")
        }
    }

    public func loadFullValuationsForRange(
        startDate: Date,
        endDate: Date,
        showQuarterly: Bool
    ) async {
        guard !currentSymbol.isEmpty else { return }

        valuationsRangeRequestId += 1
        let requestId = valuationsRangeRequestId

        isLoadingFullHistory = true
        defer { isLoadingFullHistory = false }

        do {
            let points = try await getStockAnalysisUseCase.executeValuations(
                symbol: currentSymbol,
                annualLimit: nil,
                startDate: startDate,
                endDate: endDate,
                showQuarterly: showQuarterly
            )
            guard requestId == valuationsRangeRequestId else { return }
            valuations = points
            error = nil
        } catch {
            if error is CancellationError {
                return
            }
            guard requestId == valuationsRangeRequestId else { return }
            self.error = error.toAppAlert(defaultTitle: "Lỗi Tải Dữ Liệu Định Giá Theo Khoảng")
        }
    }

    public func loadFullDividendsIfNeeded() async {
        guard !didLoadFullDividends, !isLoadingFullHistory, !currentSymbol.isEmpty else { return }
        isLoadingFullHistory = true
        defer { isLoadingFullHistory = false }

        do {
            dividends = try await getStockAnalysisUseCase.executeDividends(symbol: currentSymbol)
            didLoadFullDividends = true
            error = nil
        } catch {
            if error is CancellationError {
                return
            }
            self.error = error.toAppAlert(defaultTitle: "Lỗi Tải Dữ Liệu Cổ Tức")
        }
    }
}
