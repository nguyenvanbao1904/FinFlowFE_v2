import FinFlowCore
import SwiftUI

enum NonBankMetricYoYKind {
    case revenue
    case profit
}

extension FinancialChartsSection {
    // MARK: - Chart Renderers

    // --- Bank Asset Structure (Stacked Bar) ---
    func bankAssetChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let series: [(String, Color, (BankFinancialDataPoint) -> Double?)] = [
            ("Tiền & tương đương", AppColors.chartAssetCash, \.cashAndEquivalents),
            ("Tiền gửi NHNN", AppColors.chartCapitalDeposits, \.depositsAtSBV),
            ("Cho vay TCTD", AppColors.chartAssetTrading, \.interbankPlacements),
            ("CK kinh doanh", AppColors.chartIncomeFee, \.tradingSecurities),
            ("CK đầu tư", AppColors.chartIncomeOther, \.investmentSecurities),
            ("Cho vay KH", AppColors.chartGrowthStrong, \.customerLoans)
        ]
        return InteractiveStackedBarChart(
            items: items,
            series: series,
            yearKey: \.year,
            quarterKey: \.quarter,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- Bank Capital Structure (Stacked Bar) ---
    func bankCapitalChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let series: [(String, Color, (BankFinancialDataPoint) -> Double?)] = [
            ("Nợ CP & NHNN", AppColors.chartCapitalDeposits, \.sbvBorrowings),
            ("Tiền gửi KH", AppColors.chartGrowthStrong, \.customerDeposits),
            ("Giấy tờ có giá", AppColors.chartIncomeFee, \.valuablePapers),
            ("Vay & Gửi TCTD khác", AppColors.chartAssetTrading, \.depositsBorrowingsOthers),
            ("Vốn CSH", AppColors.chartCapitalEquity, \.equity)
        ]
        return InteractiveBankCapitalLeverageChart(
            items: items,
            series: series,
            yearKey: \.year,
            quarterKey: \.quarter,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- NonBank Asset Structure ---
    func nonBankAssetChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        InteractiveNonBankAssetQualityChart(
            items: items,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- NonBank Capital Structure (stacked + line) ---
    func nonBankCapitalChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        InteractiveNonBankCapitalStructureChart(
            items: items,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- ROE & ROA (Dual Line, dual Y-axis) ---
    func roeRoaChart(_ data: [RoeRoaPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let roeValues = data.compactMap { $0.roe }
        let roaValues = data.compactMap { $0.roa }
        let roeDomain = niceDomain(values: roeValues)
        let roaDomain = niceDomain(values: roaValues)
        return InteractiveDualLineChart(
            items: data,
            labelKey: \.periodLabel,
            line1: .init(name: "ROE", color: AppColors.chartGrowthStrong, value: \.roe),
            line2: .init(name: "ROA", color: AppColors.chartCapitalDeposits, value: \.roa),
            popoverSubtitle: "ROE & ROA",
            height: height,
            fullScreen: fullScreen,
            yDomain: roeDomain,
            yAxisFormat: .percent,
            secondaryYDomain: roaDomain
        )
    }

    /// Nice 0-based domain padded with niceStep ceiling. Falls back to 0...1 when empty.
    private func niceDomain(values: [Double]) -> ClosedRange<Double> {
        guard !values.isEmpty else { return 0...1 }
        let maxV = values.max()!
        let padded = maxV * 1.12
        let niceStep: Double = 10
        let upper = max(ceil(padded / niceStep) * niceStep, maxV + 1)
        return 0...upper
    }

    private func roeRoaYDomain(values: [Double]) -> ClosedRange<Double> {
        niceDomain(values: values)
    }

    func bankNimChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        InteractiveBankNimChart(
            items: items,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- NonBank: metric column (DT or LNST) + YoY line ---
    func nonBankRevenueYoYChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        nonBankMetricYoYChart(items, kind: .revenue, height: height, fullScreen: fullScreen)
    }

    func nonBankProfitYoYChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        nonBankMetricYoYChart(items, kind: .profit, height: height, fullScreen: fullScreen)
    }

    private func nonBankMetricYoYChart(
        _ items: [NonBankFinancialDataPoint],
        kind: NonBankMetricYoYKind,
        height: CGFloat,
        fullScreen: Bool
    ) -> some View {
        let sorted = items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        let rows = sorted.map { item -> InteractiveSingleBarYoYChart.BarYoYRow in
            let v: Double? = kind == .revenue ? item.netRevenue : item.profitAfterTax
            return .init(id: item.id.uuidString, periodLabel: item.periodLabel, value: v)
        }
        let barColor = kind == .revenue ? AppColors.chartRevenue : AppColors.chartProfit
        let barLabel = kind == .revenue ? "Doanh thu" : "LNST"
        let yoyLabel = kind == .revenue ? "Tăng trưởng DT YoY" : "Tăng trưởng LNST YoY"
        let subtitle = kind == .revenue ? "Doanh thu & tăng trưởng YoY" : "LNST & tăng trưởng YoY"
        return InteractiveSingleBarYoYChart(
            rows: rows,
            barColor: barColor,
            barLabel: barLabel,
            yoyLineColor: AppColors.chartGrowthStable,
            yoyLabel: yoyLabel,
            popoverSubtitle: subtitle,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- NonBank margins (two lines) ---
    func nonBankMarginsLineChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let sorted = items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        return InteractiveDualLineChart(
            items: sorted,
            labelKey: \.periodLabel,
            line1: .init(name: "Biên gộp %", color: AppColors.chartIncomeFee, value: \.grossMargin),
            line2: .init(name: "Biên ròng %", color: AppColors.chartCapitalEquity, value: \.netMargin),
            popoverSubtitle: "Biên LN gộp & ròng",
            height: height,
            fullScreen: fullScreen,
            yDomain: nil,
            yAxisFormat: .percent
        )
    }

    // --- Bank Profit YoY Growth (bar + line) ---
    func bankProfitYoYGrowthChart(
        _ data: [(year: Int, quarter: Int, value: Double)],
        height: CGFloat,
        fullScreen: Bool
    ) -> some View {
        let rows = data.map { p -> InteractiveSingleBarYoYChart.BarYoYRow in
            let label = (showQuarterly && p.quarter != 0) ? "Q\(p.quarter) \(p.year % 100)" : "\(p.year)"
            return .init(id: "\(p.year)-\(p.quarter)", periodLabel: label, value: p.value)
        }
        return InteractiveSingleBarYoYChart(
            rows: rows,
            barColor: AppColors.chartProfit,
            barLabel: "LNST",
            yoyLineColor: AppColors.chartGrowthStable,
            yoyLabel: "Tăng trưởng YoY",
            popoverSubtitle: "Chi tiết LNST & YoY",
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- Bank Income Structure YoY Growth (stacked bars + line) ---
    func bankIncomeYoYGrowthChart(
        _ items: [BankFinancialDataPoint],
        height: CGFloat,
        fullScreen: Bool
    ) -> some View {
        let series: [(name: String, color: Color, value: (BankFinancialDataPoint) -> Double?)] = [
            ("Lãi thuần", AppColors.chartIncomeInterest, \.netInterestIncome),
            ("Phí dịch vụ", AppColors.chartIncomeFee, \.feeAndCommissionIncome),
            ("Khác", AppColors.chartIncomeOther, \.otherIncome)
        ]
        return InteractiveBankIncomeYoYGrowthChart(
            items: items.sorted { $0.year < $1.year },
            series: series,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- Cash Flow (Stacked Bar) ---
    func cashFlowChart(_ items: [CashFlowDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let series: [(name: String, color: Color, value: (CashFlowDataPoint) -> Double?)] = [
            ("Kinh doanh", AppColors.chartGrowthStrong, \.operatingCashflow),
            ("Đầu tư", AppColors.chartIncomeFee, \.investingCashflow),
            ("Tài chính", AppColors.chartIncomeOther, \.financingCashflow)
        ]
        return InteractiveStackedBarChart(
            items: items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) },
            series: series,
            yearKey: \.year,
            quarterKey: \.quarter,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- Bank NPL (bar + line) ---
    func nplBankChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let sorted = items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        let rows = sorted.map { item -> InteractiveSingleBarYoYChart.BarYoYRow in
            .init(id: "\(item.year)-\(item.quarter)", periodLabel: item.periodLabel, value: item.nplToLoan)
        }
        return InteractiveSingleBarYoYChart(
            rows: rows,
            barColor: AppColors.expense,
            barLabel: "Tỷ lệ nợ xấu %",
            yoyLineColor: AppColors.chartGrowthStable,
            yoyLabel: "Biến động YoY",
            popoverSubtitle: "Nợ xấu & dự phòng",
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- Bank Customer Loan (bar + YoY) ---
    func customerLoanBankChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let sorted = items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        let rows = sorted.map { item -> InteractiveSingleBarYoYChart.BarYoYRow in
            .init(id: "\(item.year)-\(item.quarter)", periodLabel: item.periodLabel, value: item.customerLoan)
        }
        return InteractiveSingleBarYoYChart(
            rows: rows,
            barColor: AppColors.chartGrowthStrong,
            barLabel: "Cho vay KH",
            yoyLineColor: AppColors.chartGrowthStable,
            yoyLabel: "Tăng trưởng YoY",
            popoverSubtitle: "Cho vay khách hàng",
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- NonBank Inventory Turnover (bar + line overlay) ---
    func inventoryTurnoverChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let sorted = items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        let rows = sorted.map { item -> InteractiveSingleBarYoYChart.BarYoYRow in
            .init(id: item.id.uuidString, periodLabel: item.periodLabel, value: item.inventories)
        }
        return InteractiveSingleBarYoYChart(
            rows: rows,
            barColor: AppColors.chartRevenue,
            barLabel: "Hàng tồn kho",
            yoyLineColor: AppColors.chartGrowthStable,
            yoyLabel: "Biến động YoY",
            popoverSubtitle: "Hàng tồn kho & vòng quay",
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- Bank: Debt Group 2→5 (bar: watchlist+NPL, line: coverage) ---
    func debtGroup2to5BankChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let sorted = items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        let rows = sorted.map { item -> InteractiveSingleBarYoYChart.BarYoYRow in
            let watchlist = item.watchlistDebt ?? 0
            let nplVal = item.npl ?? 0
            let total = watchlist + nplVal
            return .init(id: "\(item.year)-\(item.quarter)", periodLabel: item.periodLabel, value: total > 0 ? total : nil)
        }
        return InteractiveSingleBarYoYChart(
            rows: rows,
            barColor: AppColors.expense,
            barLabel: "Nợ nhóm 2→5",
            yoyLineColor: AppColors.chartGrowthStable,
            yoyLabel: "Biến động YoY",
            popoverSubtitle: "Nợ nhóm 2→5",
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- Bank: NPL Structure (multi-line: substandard/doubtful/bad) ---
    func nplStructureBankChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let sorted = items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        return InteractiveMultiLineChart(
            items: sorted,
            labelKey: { $0.periodLabel },
            lines: [
                MultiLineSeries(name: "Nhóm 3 (dưới chuẩn)", color: AppColors.chartGrowthStable, value: { $0.substandardDebt }),
                MultiLineSeries(name: "Nhóm 4 (nghi ngờ)", color: AppColors.chartIncomeFee, value: { $0.doubtfulDebt }),
                MultiLineSeries(name: "Nhóm 5 (có k/n mất vốn)", color: AppColors.expense, value: { $0.badDebt })
            ],
            popoverSubtitle: "Cơ cấu nợ xấu",
            height: height,
            fullScreen: fullScreen,
            yAxisFormat: .auto,
            valueFormat: "%.0f"
        )
    }

    // --- Bank: Profitability triple-line (NIM, YOEA, COF) ---
    func profitabilityBankChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let sorted = items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        return InteractiveMultiLineChart(
            items: sorted,
            labelKey: { $0.periodLabel },
            lines: [
                MultiLineSeries(name: "NIM", color: AppColors.chartGrowthStrong, value: { $0.nim }),
                MultiLineSeries(name: "YOEA", color: AppColors.chartCapitalDeposits, value: { $0.yoea }),
                MultiLineSeries(name: "COF", color: AppColors.expense, value: { $0.cof })
            ],
            popoverSubtitle: "Chỉ số sinh lợi",
            height: height,
            fullScreen: fullScreen,
            yAxisFormat: .percent
        )
    }

    // --- Shared: Dividend chart (grouped bars: LNST + chi cổ tức) ---
    func dividendChart(
        _ data: [DividendChartRow],
        height: CGFloat,
        fullScreen: Bool
    ) -> some View {
        let series: [(name: String, color: Color, value: (DividendChartRow) -> Double?)] = [
            ("LNST", AppColors.chartProfit, \.profitAfterTax),
            ("Chi cổ tức", AppColors.chartRevenue, \.dividendPaid)
        ]
        return InteractiveStackedBarChart(
            items: data,
            series: series,
            yearKey: \.year,
            quarterKey: \.quarter,
            showQuarterly: false,
            height: height,
            fullScreen: fullScreen,
            groupedLayout: true
        )
    }
}
