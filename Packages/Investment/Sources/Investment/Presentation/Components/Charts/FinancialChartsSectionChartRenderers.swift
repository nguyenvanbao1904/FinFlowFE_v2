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
            ("Cho vay KH", AppColors.chartGrowthStrong, \.customerLoans),
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
            ("Vốn CSH", AppColors.chartCapitalEquity, \.equity),
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

    // --- ROE & ROA (Dual Line) ---
    func roeRoaChart(_ data: [RoeRoaPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let values = data.flatMap { [$0.roe, $0.roa].compactMap { $0 } }
        let domain = roeRoaYDomain(values: values)
        return InteractiveDualLineChart(
            items: data,
            labelKey: \.periodLabel,
            line1: .init(name: "ROE", color: AppColors.chartGrowthStrong, value: \.roe),
            line2: .init(name: "ROA", color: AppColors.chartCapitalDeposits, value: \.roa),
            popoverSubtitle: "ROE & ROA",
            height: height,
            fullScreen: fullScreen,
            yDomain: domain,
            yAxisFormat: .auto
        )
    }

    private func roeRoaYDomain(values: [Double]) -> ClosedRange<Double> {
        guard !values.isEmpty else { return 0...1 }
        let maxV = values.max()!
        let padded = maxV * 1.12
        let niceStep: Double = 10
        let upper = max(ceil(padded / niceStep) * niceStep, maxV + 1)
        return 0...upper
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
            ("Khác", AppColors.chartIncomeOther, \.otherIncome),
        ]
        return InteractiveBankIncomeYoYGrowthChart(
            items: items.sorted { $0.year < $1.year },
            series: series,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }
}

