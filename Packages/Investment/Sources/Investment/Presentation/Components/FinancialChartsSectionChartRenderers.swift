import FinFlowCore
import SwiftUI

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
        InteractiveRoeRoaChart(
            data: data,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
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
        InteractiveNonBankMetricYoYChart(
            kind: .revenue,
            items: items,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    func nonBankProfitYoYChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        InteractiveNonBankMetricYoYChart(
            kind: .profit,
            items: items,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- NonBank margins (two lines) ---
    func nonBankMarginsLineChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        InteractiveNonBankMarginsChart(
            items: items,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- Bank Profit YoY Growth (bar + line) ---
    func bankProfitYoYGrowthChart(
        _ data: [(year: Int, quarter: Int, value: Double)],
        height: CGFloat,
        fullScreen: Bool
    ) -> some View {
        InteractiveBankProfitYoYGrowthChart(
            points: data,
            showQuarterly: showQuarterly,
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

