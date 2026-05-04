import Foundation
import FinFlowCore
import Observation

// MARK: - Margin of Safety

public enum MoSCautionLevel: String, CaseIterable, Sendable {
    case low = "Thấp"
    case medium = "Trung bình"
    case high = "Cao"

    var multiplier: Double {
        switch self {
        case .low: return 0.85
        case .medium: return 1.0
        case .high: return 1.15
        }
    }
}

@MainActor
@Observable
public final class StockAnalysisViewModel {
    public var overview: StockOverview?
    public var shareholders: [ShareholderDataPoint] = []
    public var valuations: [ValuationDataPoint] = []
    public var dailyValuations: [DailyValuationDataPoint] = []
    public var financials: FinancialDataSeries?
    public var dividends: [DividendDataPoint] = []

    public var isLoading = false
    public var error: AppErrorAlert?
    public var isLoadingFinancials = false
    public var isLoadingValuations = false
    public var isLoadingDividends = false

    // MARK: - Dynamic MoS state
    public var mosCautionLevel: MoSCautionLevel = .medium

    /// Derived: any background history load is in progress (used by the UI loading indicator).
    public var isLoadingFullHistory: Bool {
        isLoadingFinancials || isLoadingValuations || isLoadingDividends
    }

    private let getStockAnalysisUseCase: GetStockAnalysisUseCase
    private let sessionManager: any SessionManagerProtocol
    @ObservationIgnored private let netWorthProvider: @MainActor () -> Double
    @ObservationIgnored private let portfolioValueProvider: @MainActor () -> Double
    private var currentSymbol: String = "ACB"
    private var didLoadFullFinancials = false
    private var didLoadFullValuations = false
    private var didLoadFullDividends = false
    private var valuationsRangeRequestId: Int = 0
    private var dailyValuationsRangeRequestId: Int = 0

    // MARK: - Computed MoS

    /// Tỉ lệ đầu tư/tổng tài sản (0..1). nil nếu chưa có Wealth data.
    public var allocationRatio: Double? {
        let netWorth = netWorthProvider()
        guard netWorth > 0 else { return nil }
        let portfolio = portfolioValueProvider()
        return min(portfolio / netWorth, 1.0)
    }

    /// Biên an toàn lý thuyết dựa trên tỉ lệ phân bổ (trước khi nhân caution multiplier).
    public var baseRequiredMargin: Double {
        guard let ratio = allocationRatio else { return 0.25 }
        switch ratio {
        case ..<0.20: return 0.15
        case 0.20..<0.50: return 0.25
        default: return 0.35
        }
    }

    /// Biên an toàn sau khi nhân hệ số thận trọng do user chọn.
    public var requiredMargin: Double {
        min(baseRequiredMargin * mosCautionLevel.multiplier, 0.50)
    }

    public init(
        getStockAnalysisUseCase: GetStockAnalysisUseCase,
        sessionManager: any SessionManagerProtocol,
        netWorthProvider: @escaping @MainActor () -> Double = { 0 },
        portfolioValueProvider: @escaping @MainActor () -> Double = { 0 }
    ) {
        self.getStockAnalysisUseCase = getStockAnalysisUseCase
        self.sessionManager = sessionManager
        self.netWorthProvider = netWorthProvider
        self.portfolioValueProvider = portfolioValueProvider
    }

    public func load(symbol: String = "ACB") async {
        let requestedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        currentSymbol = requestedSymbol
        didLoadFullFinancials = false
        didLoadFullValuations = false
        didLoadFullDividends = false
        valuationsRangeRequestId += 1
        dailyValuationsRangeRequestId += 1
        dailyValuations = []
        isLoading = true
        defer { isLoading = false }

        do {
            // Snapshot tab: giới hạn để payload nhẹ; backend dùng LIMIT ở SQL. Full history: loadFull*IfNeeded.
            let result = try await getStockAnalysisUseCase.execute(
                symbol: requestedSymbol,
                annualLimit: 4,
                quarterlyLimit: 13
            )
            guard requestedSymbol == currentSymbol else { return }
            overview = result.overview
            shareholders = result.shareholders
            valuations = result.valuations
            financials = result.financials
            dividends = result.dividends
            error = nil
            // Bundle snapshot caps dividends; fetch full series for charts (same as fullscreen `onRequestFullHistory`).
            Task { @MainActor in
                await loadFullDividendsIfNeeded()
            }
        } catch {
            self.error = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Tải Dữ Liệu")
        }
    }

    public func loadFullFinancialsIfNeeded() async {
        guard !didLoadFullFinancials, !isLoadingFinancials, !currentSymbol.isEmpty else { return }
        let symbol = currentSymbol
        isLoadingFinancials = true
        defer { isLoadingFinancials = false }

        do {
            let fullFinancials = try await getStockAnalysisUseCase.executeFinancialSeries(symbol: symbol)
            guard symbol == currentSymbol else { return }
            financials = fullFinancials
            didLoadFullFinancials = true
            error = nil
        } catch {
            self.error = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Tải Dữ Liệu Tài Chính")
        }
    }

    public func loadFullValuationsIfNeeded() async {
        guard !didLoadFullValuations, !isLoadingValuations, !currentSymbol.isEmpty else { return }
        let symbol = currentSymbol
        isLoadingValuations = true
        defer { isLoadingValuations = false }

        do {
            let points = try await getStockAnalysisUseCase.executeValuations(symbol: symbol)
            guard symbol == currentSymbol else { return }
            valuations = points
            didLoadFullValuations = true
            error = nil
        } catch {
            self.error = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Tải Dữ Liệu Định Giá")
        }
    }

    public func loadFullValuationsForRange(
        startDate: Date,
        endDate: Date,
        showQuarterly: Bool
    ) async {
        guard !currentSymbol.isEmpty else { return }
        let symbol = currentSymbol

        valuationsRangeRequestId += 1
        let requestId = valuationsRangeRequestId

        isLoadingValuations = true
        defer { isLoadingValuations = false }

        do {
            let points = try await getStockAnalysisUseCase.executeValuations(
                symbol: symbol,
                annualLimit: nil,
                startDate: startDate,
                endDate: endDate,
                showQuarterly: showQuarterly
            )
            guard symbol == currentSymbol, requestId == valuationsRangeRequestId else { return }
            valuations = points
            error = nil
        } catch {
            guard symbol == currentSymbol, requestId == valuationsRangeRequestId else { return }
            self.error = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Tải Dữ Liệu Định Giá Theo Khoảng")
        }
    }

    public func loadDailyValuationsForRange(startDate: Date, endDate: Date) async {
        guard !currentSymbol.isEmpty else { return }
        let symbol = currentSymbol

        dailyValuationsRangeRequestId += 1
        let requestId = dailyValuationsRangeRequestId

        isLoadingValuations = true
        defer { isLoadingValuations = false }

        do {
            let points = try await getStockAnalysisUseCase.executeDailyValuations(
                symbol: symbol,
                startDate: startDate,
                endDate: endDate
            )
            guard symbol == currentSymbol, requestId == dailyValuationsRangeRequestId else { return }
            dailyValuations = points
            error = nil
        } catch {
            guard symbol == currentSymbol, requestId == dailyValuationsRangeRequestId else { return }
            self.error = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Tải Định Giá Theo Ngày")
        }
    }

    public func loadFullDividendsIfNeeded() async {
        guard !didLoadFullDividends, !isLoadingDividends, !currentSymbol.isEmpty else { return }
        let symbol = currentSymbol
        isLoadingDividends = true
        defer { isLoadingDividends = false }

        do {
            let full = try await getStockAnalysisUseCase.executeDividends(symbol: symbol)
            guard symbol == currentSymbol else { return }
            dividends = full
            didLoadFullDividends = true
            error = nil
        } catch {
            self.error = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi Tải Dữ Liệu Cổ Tức")
        }
    }
}
