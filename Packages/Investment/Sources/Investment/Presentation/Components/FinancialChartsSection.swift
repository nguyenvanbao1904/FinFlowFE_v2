import Charts
import FinFlowCore
import SwiftUI

// MARK: - Section Orchestrator

/// Displays 6 financial chart cards adapted for Bank or NonBank data.
/// Layout: vertical scroll, each card ~200pt, with fullscreen expand.
///
/// `FinancialDataSeries` từ API đã xếp theo (year, quarter) tăng dần; chỉ sort lại khi tính toán từ nhóm/ghép cục bộ.
public struct FinancialChartsSection: View {
    let financials: FinancialDataSeries?
    let showQuarterly: Bool
    let onRequestFullHistory: (() -> Void)?
    @State private var fullscreenChart: ChartKind?

    public init(
        financials: FinancialDataSeries?,
        showQuarterly: Bool = false,
        onRequestFullHistory: (() -> Void)? = nil
    ) {
        self.financials = financials
        self.showQuarterly = showQuarterly
        self.onRequestFullHistory = onRequestFullHistory
    }

    public var body: some View {
        if let financials {
            VStack(spacing: Spacing.md) {
                switch financials {
                case .bank(let items):
                    bankCharts(items)
                case .nonBank(let items):
                    nonBankCharts(items)
                }
            }
            .fullScreenCover(item: $fullscreenChart) { kind in
                ChartFullscreenContainer(title: kind.title) {
                    GeometryReader { proxy in
                        fullscreenContent(kind: kind, size: proxy.size)
                    }
                }
            }
            .onChange(of: fullscreenChart) { _, newValue in
                guard newValue != nil else { return }
                onRequestFullHistory?()
            }
        }
    }

    // MARK: - Bank Charts

    @ViewBuilder
    private func bankCharts(_ items: [BankFinancialDataPoint]) -> some View {
        let series = items.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }

        // Row 1: Asset + Capital
        assetStructureBankCard(series)
        capitalStructureBankCard(series)

        // Row 2: ROE/ROA
        roeRoaCard(series.map { RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa) })

        // Row 3: Revenue + Profit + Income
        toiStructureBankCard(series)
        nimBankCard(series)
        let profitData = series.compactMap { item in
            item.profitAfterTax.map { (year: item.year, quarter: item.quarter, value: $0) }
        }
        profitGrowthCard(profitData)
    }

    // MARK: - NonBank Charts

    @ViewBuilder
    private func nonBankCharts(_ items: [NonBankFinancialDataPoint]) -> some View {
        let series = items.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }

        assetStructureNonBankCard(series)
        capitalStructureNonBankCard(series)
        roeRoaCard(series.map { RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa) })
        revenueYoYGrowthNonBankCard(series)
        profitYoYGrowthNonBankCard(series)
        nonBankMarginsCard(series)
    }

    // MARK: - Fullscreen Content Router

    @ViewBuilder
    private func fullscreenContent(kind: ChartKind, size: CGSize) -> some View {
        let height = ChartFullscreenSupport.preferredChartHeight(for: size)

        switch kind {
        case .assetBank:
            bankAssetChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .capitalBank:
            bankCapitalChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .roeRoa:
            roeRoaFullscreenChart(height: height)
        case .revenueYoYGrowthNonBank:
            nonBankRevenueYoYChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .profitYoYGrowthNonBank:
            nonBankProfitYoYChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .nonBankMargins:
            nonBankMarginsLineChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .profit:
            bankProfitYoYGrowthChart(bankProfitSeries(), height: height, fullScreen: true)
        case .incomeBank:
            bankIncomeYoYGrowthChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .nimBank:
            bankNimChart(filteredSortedBankSeries(), height: height, fullScreen: true)
        case .assetNonBank:
            nonBankAssetChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        case .capitalNonBank:
            nonBankCapitalChart(filteredSortedNonBankSeries(), height: height, fullScreen: true)
        }
    }

    /// Luôn lấy dữ liệu mới nhất từ `financials` để fullscreen không bị kẹt snapshot 4 quý sau khi tải full history.
    private func filteredSortedBankSeries() -> [BankFinancialDataPoint] {
        guard case .bank(let items) = financials else { return [] }
        return items.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }
    }

    private func filteredSortedNonBankSeries() -> [NonBankFinancialDataPoint] {
        guard case .nonBank(let items) = financials else { return [] }
        return items.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }
    }

    private func bankProfitSeries() -> [(year: Int, quarter: Int, value: Double)] {
        filteredSortedBankSeries().compactMap { item in
            item.profitAfterTax.map { (year: item.year, quarter: item.quarter, value: $0) }
        }
    }

    @ViewBuilder
    private func roeRoaFullscreenChart(height: CGFloat) -> some View {
        switch financials {
        case .bank:
            let pts = filteredSortedBankSeries().map {
                RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa)
            }
            roeRoaChart(pts, height: height, fullScreen: true)
        case .nonBank:
            let pts = filteredSortedNonBankSeries().map {
                RoeRoaPoint(year: $0.year, quarter: $0.quarter, roe: $0.roe, roa: $0.roa)
            }
            roeRoaChart(pts, height: height, fullScreen: true)
        case nil:
            EmptyView()
        }
    }
}

// MARK: - Chart Kind Enum (for fullscreen routing)

private struct RoeRoaPoint {
    let year: Int
    let quarter: Int
    let roe: Double?
    let roa: Double?
}

private enum ChartKind: String, Identifiable, Equatable {
    case assetBank
    case capitalBank
    case roeRoa
    case revenueYoYGrowthNonBank
    case profitYoYGrowthNonBank
    case nonBankMargins
    case profit
    case incomeBank
    case nimBank
    case assetNonBank
    case capitalNonBank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assetBank, .assetNonBank: return "Cơ cấu tài sản"
        case .capitalBank, .capitalNonBank: return "Cơ cấu nguồn vốn"
        case .roeRoa: return "ROE & ROA"
        case .revenueYoYGrowthNonBank: return "Doanh thu & tăng trưởng YoY"
        case .profitYoYGrowthNonBank: return "LNST & tăng trưởng YoY"
        case .nonBankMargins: return "Biên LN gộp & ròng"
        case .profit: return "Lợi nhuận hàng năm"
        case .incomeBank: return "Cơ cấu TOI"
        case .nimBank: return "Bức tranh biên lãi"
        }
    }
}

// MARK: - Card Builders (Bank)

private extension FinancialChartsSection {

    func assetStructureBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        chartCard(title: "Cơ cấu tài sản", expandKind: .assetBank) {
            bankAssetChart(items, height: 200, fullScreen: false)
        }
    }

    func capitalStructureBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let eq = last.equity, eq > 0 {
            // Tách expression để SwiftUI type-check nhanh hơn.
            let customerDeposits = last.customerDeposits ?? 0
            let valuablePapers = last.valuablePapers ?? 0
            let depositsBorrowingsOthers = last.depositsBorrowingsOthers ?? 0
            let sbvBorrowings = last.sbvBorrowings ?? 0
            let fallbackLiab =
                customerDeposits
                + valuablePapers
                + depositsBorrowingsOthers
                + sbvBorrowings
            let liab = last.totalLiabilities ?? fallbackLiab
            let leverage = (liab + eq) / eq
            subtitle = String(format: "Đòn bẩy TS/VCSH: %.1f lần", leverage)
        }
        return chartCard(title: "Cơ cấu nguồn vốn", subtitle: subtitle, expandKind: .capitalBank) {
            bankCapitalChart(items, height: 200, fullScreen: false)
        }
    }

    func toiStructureBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let totalIncomeByPeriod: [(year: Int, value: Double)] = items.compactMap { item in
            let parts = [item.netInterestIncome, item.feeAndCommissionIncome, item.otherIncome].compactMap { $0 }
            guard !parts.isEmpty else { return nil }
            return (year: item.year, value: parts.reduce(0, +))
        }
        let totalIncome = aggregateYearlyFlow(totalIncomeByPeriod)
        let cagrInfo = computeRecentCAGR(totalIncome, targetYears: 5)
        let subtitle = cagrInfo.map { recent in
            String(
                format: "Tăng trưởng kép bình quân %d năm (%d-%d): %.1f%%/năm",
                recent.years,
                recent.startYear,
                recent.endYear,
                recent.rate
            )
        }
        let subtitleColor = growthSubtitleColor(for: cagrInfo?.rate)

        return chartCard(
            title: "Cơ cấu TOI",
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            expandKind: .incomeBank
        ) {
            bankIncomeYoYGrowthChart(items, height: 200, fullScreen: false)
        }
    }

    func nimBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let nii = last.netInterestIncome, let assets = last.totalAssets, assets > 0 {
            subtitle = String(format: "NIM (Ước tính TTM): %.2f%%", (nii * 4.0 / assets) * 100)
        }
        return chartCard(title: "Bức tranh biên lãi", subtitle: subtitle, expandKind: .nimBank) {
            bankNimChart(items, height: 200, fullScreen: false)
        }
    }
}

// MARK: - Card Builders (NonBank)

private extension FinancialChartsSection {

    func assetStructureNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let ta = last.totalAssets, ta > 0 {
            let pthu = (last.shortTermReceivables ?? 0) + (last.longTermReceivables ?? 0)
            subtitle = String(format: "Phải thu / Tổng TS: %.1f%%", (pthu / ta) * 100)
        }
        return chartCard(title: "Cơ cấu tài sản", subtitle: subtitle, expandKind: .assetNonBank) {
            nonBankAssetChart(items, height: 200, fullScreen: false)
        }
    }

    func capitalStructureNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let eq = last.equity, eq != 0 {
            let shortBorrow = last.shortTermBorrowings ?? 0
            let longBorrow = last.longTermBorrowings ?? 0
            let cash = last.cashAndEquivalents ?? 0
            let shortInvest = last.shortTermInvestments ?? 0
            let netDebt = (shortBorrow + longBorrow) - (cash + shortInvest)
            let ratio = (netDebt / eq) * 100
            subtitle = String(format: "Nợ vay ròng / VCSH: %.1f%%", ratio)
        }
        return chartCard(title: "Cơ cấu nguồn vốn", subtitle: subtitle, expandKind: .capitalNonBank) {
            nonBankCapitalChart(items, height: 200, fullScreen: false)
        }
    }

    func revenueYoYGrowthNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        var subtitleColor: Color = AppColors.success
        let yearlyRevenue = aggregateYearlyFlow(
            sorted.compactMap { item -> (year: Int, value: Double)? in
                guard let v = item.netRevenue else { return nil }
                return (year: item.year, value: v)
            }
        )
        if let recent = computeRecentCAGR(yearlyRevenue, targetYears: 5) {
            subtitle = String(
                format: "Tăng trưởng kép bình quân %d năm (%d-%d): %.1f%%/năm",
                recent.years,
                recent.startYear,
                recent.endYear,
                recent.rate
            )
            subtitleColor = growthSubtitleColor(for: recent.rate)
        }
        return chartCard(
            title: "Doanh thu & tăng trưởng YoY",
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            expandKind: .revenueYoYGrowthNonBank
        ) {
            nonBankRevenueYoYChart(items, height: 200, fullScreen: false)
        }
    }



    func profitYoYGrowthNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        var subtitleColor: Color = AppColors.success
        let yearlyProfit = aggregateYearlyFlow(
            sorted.compactMap { item -> (year: Int, value: Double)? in
                guard let v = item.profitAfterTax else { return nil }
                return (year: item.year, value: v)
            }
        )
        if let recent = computeRecentCAGR(yearlyProfit, targetYears: 5) {
            subtitle = String(
                format: "Tăng trưởng kép bình quân %d năm (%d-%d): %.1f%%/năm",
                recent.years,
                recent.startYear,
                recent.endYear,
                recent.rate
            )
            subtitleColor = growthSubtitleColor(for: recent.rate)
        }
        return chartCard(
            title: "LNST & tăng trưởng YoY",
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            expandKind: .profitYoYGrowthNonBank
        ) {
            nonBankProfitYoYChart(items, height: 200, fullScreen: false)
        }
    }

    func nonBankMarginsCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last {
            var parts: [String] = []
            if let g = last.grossMargin {
                parts.append(String(format: "Biên Gộp: %.1f%%", g))
            }
            if let n = last.netMargin {
                parts.append(String(format: "Biên Ròng: %.1f%%", n))
            }
            subtitle = parts.isEmpty ? nil : parts.joined(separator: " • ")
        }
        return chartCard(
            title: "Biên LN gộp & ròng",
            subtitle: subtitle,
            expandKind: .nonBankMargins
        ) {
            nonBankMarginsLineChart(items, height: 200, fullScreen: false)
        }
    }
}

// MARK: - Shared Card Builders

private extension FinancialChartsSection {

    func roeRoaCard(_ data: [RoeRoaPoint]) -> some View {
        let sorted = data.sorted { 
            if $0.year != $1.year { return $0.year < $1.year }
            return $0.quarter < $1.quarter
        }
        var subtitle: String?
        if let last = sorted.last {
            // Backend/iOS already normalized to percent (e.g. 0.18 -> 18.0), so không nhân thêm *100.
            let roeStr = last.roe != nil ? String(format: "ROE: %.1f%%", last.roe!) : nil
            let roaStr = last.roa != nil ? String(format: "ROA: %.1f%%", last.roa!) : nil
            subtitle = [roeStr, roaStr].compactMap { $0 }.joined(separator: " • ")
        }
        let sub = subtitle?.isEmpty == false ? subtitle : nil
        return chartCard(title: "ROE & ROA", subtitle: sub, expandKind: .roeRoa) {
            roeRoaChart(data, height: 200, fullScreen: false)
        }
    }

    func profitGrowthCard(_ data: [(year: Int, quarter: Int, value: Double)]) -> some View {
        let sorted = data.sorted { 
            if $0.year != $1.year { return $0.year < $1.year }
            return $0.quarter < $1.quarter
        }
        let yearlyProfit = aggregateYearlyFlow(
            sorted.map { (year: $0.year, value: $0.value) }
        )
        let cagrInfo = computeRecentCAGR(yearlyProfit, targetYears: 5)
        let cagrStr: String? = cagrInfo.map { recent in
            String(
                format: "Tăng trưởng kép bình quân %d năm (%d-%d): %.1f%%/năm",
                recent.years,
                recent.startYear,
                recent.endYear,
                recent.rate
            )
        }
        let sub = cagrStr
        let subtitleColor = growthSubtitleColor(for: cagrInfo?.rate)

        return chartCard(
            title: "Lợi nhuận hàng năm",
            subtitle: sub?.isEmpty == false ? sub : nil,
            subtitleColor: subtitleColor,
            expandKind: .profit
        ) {
            bankProfitYoYGrowthChart(data, height: 200, fullScreen: false)
        }
    }
}

// MARK: - Chart Renderers

private extension FinancialChartsSection {

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
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- NonBank Capital Structure (stacked + đường nợ vay ròng / VCSH) ---
    func nonBankCapitalChart(_ items: [NonBankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        InteractiveNonBankCapitalStructureChart(
            items: items,
            showQuarterly: showQuarterly,
            height: height,
            fullScreen: fullScreen
        )
    }

    // --- ROE & ROA (Dual Line) ---
    func roeRoaChart(_ data: [RoeRoaPoint], height: CGFloat, fullScreen: Bool) -> some View {
        return InteractiveRoeRoaChart(
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

    // --- Bank Revenue (Stacked Bar: interest + fee + other) ---
    func bankRevenueChart(_ items: [BankFinancialDataPoint], height: CGFloat, fullScreen: Bool) -> some View {
        let series: [(String, Color, (BankFinancialDataPoint) -> Double?)] = [
            ("Lãi thuần", AppColors.chartIncomeInterest, \.netInterestIncome),
            ("Phí dịch vụ", AppColors.chartIncomeFee, \.feeAndCommissionIncome),
            ("Thu nhập khác", AppColors.chartIncomeOther, \.otherIncome),
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

    // --- NonBank: cột một chỉ tiêu (DT hoặc LNST) + đường YoY (%) ---
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

    /// Hai đường biên gộp % và biên ròng %.
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
        return InteractiveBankProfitYoYGrowthChart(
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

// MARK: - Chart Card Wrapper

private extension FinancialChartsSection {

    func chartCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        subtitleColor: Color = AppColors.success,
        expandKind: ChartKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption2)
                            .foregroundStyle(subtitleColor)
                    }
                }
                Spacer()
                Button {
                    fullscreenChart = expandKind
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Circle())
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Phóng to biểu đồ \(title)")
            }

            content()
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: Spacing.xs)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(AppTypography.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Helpers

private extension FinancialChartsSection {
    struct RecentCAGRInfo {
        let rate: Double
        let years: Int
        let startYear: Int
        let endYear: Int
    }

    func formatAxis(_ value: Double) -> String {
        formatVndCompact(value)
    }

    func computeCAGR(_ values: [Double]) -> Double? {
        guard values.count >= 2,
              let first = values.first, first > 0,
              let last = values.last, last > 0
        else { return nil }
        let n = Double(values.count - 1)
        return (pow(last / first, 1.0 / n) - 1.0) * 100
    }

    /// CAGR cho cửa sổ gần nhất (mặc định 5 năm), tính theo chênh lệch năm thực.
    func computeRecentCAGR(_ yearlyValues: [(year: Int, value: Double)], targetYears: Int = 5) -> RecentCAGRInfo? {
        guard let latestYear = yearlyValues.map(\.year).max() else { return nil }
        let lowerBoundYear = latestYear - targetYears
        let window = yearlyValues
            .filter { $0.year >= lowerBoundYear }
            .sorted { $0.year < $1.year }
        guard
            let first = window.first,
            let last = window.last,
            first.value > 0,
            last.value > 0
        else { return nil }
        let years = max(last.year - first.year, 0)
        guard years > 0 else { return nil }
        let n = Double(years)
        let rate = (pow(last.value / first.value, 1.0 / n) - 1.0) * 100
        return RecentCAGRInfo(
            rate: rate,
            years: years,
            startYear: first.year,
            endYear: last.year
        )
    }

    func growthSubtitleColor(for rate: Double?) -> Color {
        guard let rate else { return .secondary }
        if rate < 0 { return .red }
        if rate < 7 { return .orange }
        return AppColors.success
    }

    /// Dùng cho chỉ tiêu dòng tiền/KQKD: nếu dữ liệu theo quý thì cộng 4 quý thành năm trước khi tính CAGR.
    func aggregateYearlyFlow(_ values: [(year: Int, value: Double)]) -> [(year: Int, value: Double)] {
        Dictionary(grouping: values, by: \.year)
            .map { year, grouped in
                (year: year, value: grouped.reduce(0) { $0 + $1.value })
            }
            .sorted { $0.year < $1.year }
    }

}

/// Công thức chung cho trục Y chart cột: miền dữ liệu thực + 10% headroom.
private func unifiedBarDomain(values: [Double], floorAtZero: Bool = true) -> ClosedRange<Double> {
    let finite = values.filter(\.isFinite)
    guard !finite.isEmpty else { return 0...1 }

    var minVal = finite.min() ?? 0
    var maxVal = finite.max() ?? 0
    if floorAtZero {
        minVal = min(0, minVal)
        maxVal = max(0, maxVal)
    }

    let span = max(maxVal - minVal, 1)
    return minVal...(maxVal + span * 0.10)
}

private func recentScrollStartLabel(labels: [String], visibleLength: Int) -> String {
    guard !labels.isEmpty else { return "" }
    let startIndex = max(labels.count - visibleLength, 0)
    return labels[startIndex]
}

private struct InteractiveStackedBarChart<Item>: View {
    let items: [Item]
    let series: [(name: String, color: Color, value: (Item) -> Double?)]
    let yearKey: KeyPath<Item, Int>
    let quarterKey: KeyPath<Item, Int>?
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool
    /// Thêm dòng vào popover fullscreen (vd: tổng tài sản).
    let extraPopoverMetrics: ((Item) -> [ChartPopoverMetric])?

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    init(
        items: [Item],
        series: [(name: String, color: Color, value: (Item) -> Double?)],
        yearKey: KeyPath<Item, Int>,
        quarterKey: KeyPath<Item, Int>? = nil,
        showQuarterly: Bool = false,
        height: CGFloat,
        fullScreen: Bool,
        extraPopoverMetrics: ((Item) -> [ChartPopoverMetric])? = nil
    ) {
        self.items = items
        self.series = series
        self.yearKey = yearKey
        self.quarterKey = quarterKey
        self.showQuarterly = showQuarterly
        self.height = height
        self.fullScreen = fullScreen
        self.extraPopoverMetrics = extraPopoverMetrics
    }

    private var labels: [String] {
        items.map { item in
            let y = item[keyPath: yearKey]
            if showQuarterly, let qKey = quarterKey {
                let q = item[keyPath: qKey]
                return "Q\(q) \(y % 100)"
            }
            return "\(y)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, items.count)) : min(4, max(1, items.count)) }
    private var legendReserved: CGFloat {
        if series.count <= 3 { return 26 }
        if series.count <= 6 { return 52 }
        return 78
    }
    private var chartHeight: CGFloat {
        if fullScreen {
            // Chừa thêm không gian cho phần chi tiết khi đang fullscreen.
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }
    private var barDomain: ClosedRange<Double> {
        let stackedTotals = items.map { item in
            series.reduce(0) { acc, s in
                acc + max(0, s.value(item) ?? 0)
            }
        }
        return unifiedBarDomain(values: stackedTotals)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            stackedChart
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text(Self.formatAxis(v)) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartYScale(domain: barDomain)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: min(series.count, 3))
            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    chartLegendItem(s.name, color: s.color)
                }
            }
            .frame(height: legendReserved, alignment: .top)

        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let metrics = selectionMetrics(for: label) {
                nativeSelectionDetails(
                    title: label,
                    subtitle: "Chi tiết thành phần",
                    metrics: metrics
                )
                .frame(maxWidth: 280)
                .padding(.top, Spacing.sm)
                .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }

    private var stackedChart: some View {
        let indexedItems = Array(items.enumerated())
        let indexedSeries = Array(series.enumerated())
        return Chart {
            ForEach(indexedItems, id: \.offset) { idx, item in
                let label = labels[idx]
                ForEach(indexedSeries, id: \.offset) { _, s in
                    if let v = s.value(item) {
                        BarMark(x: .value("Kỳ", label), y: .value(s.name, v))
                            .foregroundStyle(s.color)
                    }
                }
            }
        }
    }

    private func selectionMetrics(for label: String) -> [ChartPopoverMetric]? {
        guard let idx = labels.firstIndex(of: label), items.indices.contains(idx) else { return nil }
        let item = items[idx]
        let baseMetrics = series.compactMap { s -> ChartPopoverMetric? in
            guard let v = s.value(item) else { return nil }
            return ChartPopoverMetric(id: s.name, label: s.name, value: formatVndCompact(v), color: s.color)
        }
        let extra = extraPopoverMetrics?(item) ?? []
        return extra + baseMetrics
    }

    private static func formatAxis(_ value: Double) -> String {
        formatVndCompact(value)
    }
}

private struct InteractiveBankCapitalLeverageChart: View {
    let items: [BankFinancialDataPoint]
    let series: [(name: String, color: Color, value: (BankFinancialDataPoint) -> Double?)]
    let yearKey: KeyPath<BankFinancialDataPoint, Int>
    let quarterKey: KeyPath<BankFinancialDataPoint, Int>?
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    init(
        items: [BankFinancialDataPoint],
        series: [(name: String, color: Color, value: (BankFinancialDataPoint) -> Double?)],
        yearKey: KeyPath<BankFinancialDataPoint, Int>,
        quarterKey: KeyPath<BankFinancialDataPoint, Int>? = nil,
        showQuarterly: Bool = false,
        height: CGFloat,
        fullScreen: Bool
    ) {
        self.items = items
        self.series = series
        self.yearKey = yearKey
        self.quarterKey = quarterKey
        self.showQuarterly = showQuarterly
        self.height = height
        self.fullScreen = fullScreen
    }

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private let leverageLineColor: Color = Color.primary
    private let leverageTicks: [Double] = [5, 8, 11, 14, 17, 20]
    private let leverageMin: Double = 5
    private let leverageMax: Double = 20

    private var labels: [String] {
        items.map { item in
            let y = item[keyPath: yearKey]
            if showQuarterly, let qKey = quarterKey {
                let q = item[keyPath: qKey]
                return "Q\(q) \(y % 100)"
            }
            return "\(y)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, items.count)) : min(4, max(1, items.count)) }

    private var legendReserved: CGFloat {
        let count = series.count + 1 // + line leverage
        if count <= 3 { return 26 }
        if count <= 6 { return 52 }
        return 78
    }
    private var chartHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    /// Trục Y cho bar (đơn vị VND tỷ).
    private var barDomain: ClosedRange<Double> {
        let totals = items.map { item in
            series.reduce(0) { acc, s in
                acc + (s.value(item) ?? 0)
            }
        }
        return unifiedBarDomain(values: totals)
    }

    private func clampLeverage(_ r: Double) -> Double {
        min(max(r, leverageMin), leverageMax)
    }

    /// Map leverage (5x...20x) -> y coordinate (cùng miền barDomain).
    private func leverageToY(_ r: Double) -> Double {
        let yMin = barDomain.lowerBound
        let yMax = barDomain.upperBound
        let span = max(yMax - yMin, 1e-9)
        let t = (clampLeverage(r) - leverageMin) / max(leverageMax - leverageMin, 1e-9)
        return yMin + t * span
    }

    private func yToLeverage(_ y: Double) -> Double {
        let yMin = barDomain.lowerBound
        let yMax = barDomain.upperBound
        let span = max(yMax - yMin, 1e-9)
        let t = (y - yMin) / span
        return leverageMin + t * (leverageMax - leverageMin)
    }

    private func leverageRatio(for item: BankFinancialDataPoint) -> Double? {
        guard let assets = item.totalAssets, let eq = item.equity, eq != 0 else { return nil }
        return assets / eq
    }

    private var leverageTickYs: [Double] { leverageTicks.map(leverageToY) }

    /// Tách `Chart` khỏi `body` để compiler type-check nhanh (nested ForEach + dual axis).
    private var capitalLeverageChartMarks: some View {
        Chart {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                let label = labels[idx]
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    if let v = s.value(item) {
                        BarMark(x: .value("Kỳ", label), y: .value(s.name, v))
                            .foregroundStyle(s.color)
                    }
                }
            }
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                if let r = leverageRatio(for: item) {
                    let label = labels[idx]
                    LineMark(
                        x: .value("Kỳ", label),
                        y: .value("TS/VCSH", leverageToY(r))
                    )
                    .foregroundStyle(leverageLineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Kỳ", label),
                        y: .value("TS/VCSH", leverageToY(r))
                    )
                    .foregroundStyle(leverageLineColor)
                    .symbolSize(30)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            capitalLeverageChartMarks
            .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatVndCompact(v))
                                .font(AppTypography.caption2)
                                .offset(x: Spacing.xs)
                        }
                    }
                }

                AxisMarks(position: .leading, values: leverageTickYs) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let y = value.as(Double.self) {
                            let r = yToLeverage(y)
                            Text("\(Int(round(r)))x")
                                .font(AppTypography.caption2)
                                .offset(x: -Spacing.xs)
                        }
                    }
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            let legendItems: [(String, Color)] = series.map { ($0.name, $0.color) } + [("TS/VCSH", leverageLineColor)]
            let columnsCount = min(legendItems.count, 3)
            let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: columnsCount)
            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                ForEach(Array(legendItems.enumerated()), id: \.offset) { _, it in
                    chartLegendItem(it.0, color: it.1)
                }
            }
            .frame(height: legendReserved, alignment: .top)

        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let metrics = selectionMetrics(for: label) {
                nativeSelectionDetails(
                    title: label,
                    subtitle: "Chi tiết thành phần",
                    metrics: metrics
                )
                .frame(maxWidth: 280)
                .padding(.top, Spacing.sm)
                .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }

    private func selectionMetrics(for label: String) -> [ChartPopoverMetric]? {
        guard let idx = labels.firstIndex(of: label), items.indices.contains(idx) else { return nil }
        let item = items[idx]

        let baseMetrics = series.compactMap { s -> ChartPopoverMetric? in
            guard let v = s.value(item) else { return nil }
            return ChartPopoverMetric(
                id: s.name,
                label: s.name,
                value: formatVndCompact(v),
                color: s.color
            )
        }

        let leverageMetrics: [ChartPopoverMetric] = leverageRatio(for: item).map { r in
            let clamped = clampLeverage(r)
            let text = "\(String(format: "%.2f", r))x"
            return ChartPopoverMetric(
                id: "leverage",
                label: "Đòn bẩy TS/VCSH",
                value: text + (abs(r - clamped) > 1e-9 ? " (clamp)" : ""),
                color: leverageLineColor
            )
        }.map { [$0] } ?? []

        let totalLiabMetrics: [ChartPopoverMetric] = item.totalLiabilities.map { v in
            [ChartPopoverMetric(id: "liab", label: "Tổng nợ phải trả", value: formatVndCompact(v), color: Color.red)]
        } ?? []

        return baseMetrics + totalLiabMetrics + leverageMetrics
    }
}

private struct InteractiveSingleBarChart: View {
    let points: [(year: Int, value: Double)]
    let height: CGFloat
    let fullScreen: Bool
    let metricId: String
    let metricLabel: String
    let color: Color
    let valueFormatter: (Double) -> String
    let axisFormatter: (Double) -> String

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private var labels: [String] { points.map { String($0.year) } }
    private var visibleLength: Int { fullScreen ? min(8, max(1, points.count)) : min(4, max(1, points.count)) }
    private let legendReserved: CGFloat = 26
    private var chartHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart(Array(points.enumerated()), id: \.offset) { idx, d in
                BarMark(x: .value("Năm", labels[idx]), y: .value(metricLabel, d.value))
                    .foregroundStyle(color)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text(axisFormatter(v)) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            chartLegendItem(metricLabel, color: color)
                .frame(height: legendReserved, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let idx = labels.firstIndex(of: label), points.indices.contains(idx) {
                let metric = ChartPopoverMetric(
                    id: metricId,
                    label: metricLabel,
                    value: valueFormatter(points[idx].value),
                    color: color
                )
                nativeSelectionDetails(title: label, subtitle: metricLabel, metrics: [metric])
                    .frame(maxWidth: 280)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }
}

// MARK: - Bank: LNST + tăng trưởng YoY (%)

private struct InteractiveBankProfitYoYGrowthChart: View {
    let points: [(year: Int, quarter: Int, value: Double)]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    private struct Row: Identifiable {
        let id: Int
        let year: Int
        let value: Double?
    }

    private struct YoYRow: Identifiable {
        let id: Int
        let year: Int
        let yoy: Double?
    }

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private let barColor: Color = AppColors.chartProfit
    private let yoyLineColor: Color = AppColors.chartGrowthStable
    private let legendReserved: CGFloat = 52

    private var rows: [Row] {
        points.map { Row(id: $0.year, year: $0.year, value: $0.value) }
    }

    private var yoyRows: [YoYRow] {
        var out: [YoYRow] = []
        for i in rows.indices {
            let cur = rows[i]
            var yoy: Double?
            if i > 0, let c = cur.value, let p = rows[i - 1].value, p != 0 {
                yoy = (c - p) / p * 100
            }
            out.append(YoYRow(id: cur.id, year: cur.year, yoy: yoy))
        }
        return out
    }

    private var labels: [String] {
        points.enumerated().map { idx, p in
            if showQuarterly && p.quarter != 0 {
                return "Q\(p.quarter) \(p.year % 100)"
            }
            return "\(p.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, rows.count)) : min(4, max(1, rows.count)) }
    private var chartPlotHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    private var barDomain: ClosedRange<Double> {
        let vals = rows.compactMap(\.value)
        return unifiedBarDomain(values: vals)
    }

    private let yoyDomain: ClosedRange<Double> = -100 ... 100

    private func clampYoYForPlot(_ pct: Double) -> Double {
        min(max(pct, yoyDomain.lowerBound), yoyDomain.upperBound)
    }

    private func scaleYoYToBarDomain(_ yoy: Double) -> Double {
        let yoyClamped = clampYoYForPlot(yoy)
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = bMax - bMin
        let yMin = yoyDomain.lowerBound
        let ySpan = yoyDomain.upperBound - yMin
        return bMin + ((yoyClamped - yMin) / ySpan) * bSpan
    }

    private func scaleBarDomainToYoY(_ mappedY: Double) -> Double {
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = max(bMax - bMin, 1e-9)
        let yMin = yoyDomain.lowerBound
        let ySpan = yoyDomain.upperBound - yMin
        return yMin + ((mappedY - bMin) / bSpan) * ySpan
    }



    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    if let v = row.value {
                        BarMark(
                            x: .value("Kỳ", labels[idx]),
                            y: .value("Giá trị", v)
                        )
                        .foregroundStyle(barColor)
                    }
                }

                RuleMark(y: .value("0%", scaleYoYToBarDomain(0)))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

                ForEach(Array(yoyRows.enumerated()), id: \.offset) { idx, y in
                    if let rv = y.yoy {
                        let scaled = scaleYoYToBarDomain(rv)
                        LineMark(
                            x: .value("Kỳ", labels[idx]),
                            y: .value("YoY", scaled)
                        )
                        .foregroundStyle(yoyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Kỳ", labels[idx]),
                            y: .value("YoY", scaled)
                        )
                        .foregroundStyle(yoyLineColor)
                        .symbolSize(36)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatVndCompact(v))
                                .font(AppTypography.caption2)
                                .offset(x: Spacing.xs)
                        }
                    }
                }
                
                AxisMarks(
                    position: .leading,
                    values: [-100.0, -50.0, 0.0, 50.0, 100.0].map { scaleYoYToBarDomain($0) }
                ) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let mappedV = value.as(Double.self) {
                            let yoy = scaleBarDomainToYoY(mappedV)
                            Text("\(Int(round(yoy)))%")
                                .font(AppTypography.caption2)
                                .offset(x: -Spacing.xs)
                        }
                    }
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartPlotHeight)

            HStack(spacing: Spacing.md) {
                chartLegendItem("LNST", color: barColor)
                chartLegendItem("Tăng trưởng YoY", color: yoyLineColor)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: legendReserved, alignment: .center)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let idx = labels.firstIndex(of: label), rows.indices.contains(idx) {
                let row = rows[idx]
                let yoy = yoyRows.indices.contains(idx) ? yoyRows[idx].yoy : nil
                nativeSelectionDetails(
                    title: label,
                    subtitle: "Chi tiết LNST & YoY",
                    metrics: popoverMetrics(row: row, yoy: yoy)
                )
                .frame(maxWidth: 280)
                .padding(.top, Spacing.sm)
                .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }

    private func popoverMetrics(row: Row, yoy: Double?) -> [ChartPopoverMetric] {
        var m: [ChartPopoverMetric] = []
        if let v = row.value {
            m.append(ChartPopoverMetric(
                id: "pat",
                label: "LNST",
                value: formatVndCompact(v),
                color: barColor
            ))
        }
        m.append(ChartPopoverMetric(
            id: "yoy",
            label: "Tăng trưởng YoY",
            value: yoy.map { String(format: "%.2f%%", $0) } ?? "—",
            color: yoyLineColor
        ))
        return m
    }
}

// MARK: - Bank: Cơ cấu TOI + tăng trưởng YoY (%)

private struct InteractiveBankIncomeYoYGrowthChart: View {
    let items: [BankFinancialDataPoint]
    let series: [(name: String, color: Color, value: (BankFinancialDataPoint) -> Double?)]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private let yoyLineColor: Color = AppColors.chartGrowthStrong
    private let legendReserved: CGFloat = 52

    /// Thứ tự khớp backend: (year, quarter) tăng dần.
    private var sortedItems: [BankFinancialDataPoint] { items }

    private struct Row: Identifiable {
        let id: Int
        let year: Int
        let totalIncome: Double?
    }

    private struct YoYRow: Identifiable {
        let id: Int
        let year: Int
        let yoy: Double?
    }

    private struct SeriesItem: Identifiable {
        let id: Int
        let name: String
        let color: Color
        let value: (BankFinancialDataPoint) -> Double?
    }

    private var seriesItems: [SeriesItem] {
        series.enumerated().map { offset, element in
            SeriesItem(
                id: offset,
                name: element.name,
                color: element.color,
                value: element.value
            )
        }
    }

    private struct BarPlotPoint: Identifiable {
        let id: String
        let year: Int
        let yearLabel: String
        let name: String
        let color: Color
        let value: Double
    }

    private var barPlotPoints: [BarPlotPoint] {
        sortedItems.flatMap { item in
            seriesItems.compactMap { s in
                s.value(item).map { v in
                    BarPlotPoint(
                        id: "\(item.year)-\(s.name)",
                        year: item.year,
                        yearLabel: String(item.year),
                        name: s.name,
                        color: s.color,
                        value: v
                    )
                }
            }
        }
    }

    private struct YoYPlotPoint: Identifiable {
        let id: Int
        /// Chỉ số hàng trong `rows` / `labels` (không phải index sau compactMap).
        let rowIndex: Int
        let year: Int
        let yearLabel: String
        let scaled: Double
    }

    private var yoyPlotPoints: [YoYPlotPoint] {
        yoyRows.enumerated().compactMap { i, y in
            guard let rv = y.yoy else { return nil }
            return YoYPlotPoint(
                id: y.id,
                rowIndex: i,
                year: y.year,
                yearLabel: String(y.year),
                scaled: scaleYoYToBarDomain(rv)
            )
        }
    }

    private var rows: [Row] {
        sortedItems.map { item in
            let parts = seriesItems.compactMap { $0.value(item) }
            let total = parts.isEmpty ? nil : parts.reduce(0, +)
            return Row(id: item.year, year: item.year, totalIncome: total)
        }
    }

    private var yoyRows: [YoYRow] {
        var out: [YoYRow] = []
        for i in rows.indices {
            let cur = rows[i]
            var yoy: Double?
            if i > 0,
               let c = cur.totalIncome,
               let p = rows[i - 1].totalIncome,
               p != 0 {
                yoy = (c - p) / p * 100
            }
            out.append(YoYRow(id: cur.id, year: cur.year, yoy: yoy))
        }
        return out
    }

    private var labels: [String] {
        rows.indices.map { idx in
            let item = sortedItems[idx]
            if showQuarterly && item.quarter != 0 {
                return "Q\(item.quarter) \(item.year % 100)"
            }
            return "\(item.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, rows.count)) : min(4, max(1, rows.count)) }
    private var chartPlotHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    private var zeroYoYMapped: Double { scaleYoYToBarDomain(0) }
    private var yoyAxisValues: [Double] {
        [-100.0, -50.0, 0.0, 50.0, 100.0].map { scaleYoYToBarDomain($0) }
    }
    private var legendItems: [(String, Color)] {
        seriesItems.map { ($0.name, $0.color) } + [("Tăng trưởng YoY", yoyLineColor)]
    }

    private var barDomain: ClosedRange<Double> {
        let vals = rows.compactMap(\.totalIncome)
        return unifiedBarDomain(values: vals)
    }

    private let yoyDomain: ClosedRange<Double> = -100 ... 100

    private func clampYoYForPlot(_ pct: Double) -> Double {
        min(max(pct, yoyDomain.lowerBound), yoyDomain.upperBound)
    }

    private func scaleYoYToBarDomain(_ yoy: Double) -> Double {
        let yoyClamped = clampYoYForPlot(yoy)
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = bMax - bMin
        let yMin = yoyDomain.lowerBound
        let ySpan = yoyDomain.upperBound - yMin
        return bMin + ((yoyClamped - yMin) / ySpan) * bSpan
    }

    private func scaleBarDomainToYoY(_ mappedY: Double) -> Double {
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = max(bMax - bMin, 1e-9)
        let yMin = yoyDomain.lowerBound
        let ySpan = yoyDomain.upperBound - yMin
        return yMin + ((mappedY - bMin) / bSpan) * ySpan
    }



    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                // Stacked bar: các thành phần TOI
                ForEach(Array(sortedItems.enumerated()), id: \.offset) { idx, item in
                    let label = labels[idx]
                    ForEach(seriesItems) { s in
                        if let v = s.value(item) {
                            BarMark(x: .value("Kỳ", label), y: .value(s.name, v))
                                .foregroundStyle(s.color)
                        }
                    }
                }

                // 0% line
                RuleMark(y: .value("0%", zeroYoYMapped))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

                // YoY line
                ForEach(yoyPlotPoints) { p in
                    let label = labels.indices.contains(p.rowIndex) ? labels[p.rowIndex] : String(p.year)
                    LineMark(
                        x: .value("Kỳ", label),
                        y: .value("YoY", p.scaled)
                    )
                    .foregroundStyle(yoyLineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Kỳ", label),
                        y: .value("YoY", p.scaled)
                    )
                    .foregroundStyle(yoyLineColor)
                    .symbolSize(36)
                }
            }
            .chartLegend(.hidden)
            .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatVndCompact(v))
                                .font(AppTypography.caption2)
                                .offset(x: Spacing.xs)
                        }
                    }
                }
                
                AxisMarks(
                    position: .leading,
                    values: yoyAxisValues
                ) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let mappedV = value.as(Double.self) {
                            let yoy = scaleBarDomainToYoY(mappedV)
                            Text("\(Int(round(yoy)))%")
                                .font(AppTypography.caption2)
                                .offset(x: -Spacing.xs)
                        }
                    }
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartPlotHeight)

            let columnsCount = min(legendItems.count, 3)
            let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: columnsCount)

            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                ForEach(Array(legendItems.enumerated()), id: \.offset) { _, it in
                    chartLegendItem(it.0, color: it.1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: legendReserved, alignment: .center)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel,
               let idx = labels.firstIndex(of: label),
               rows.indices.contains(idx),
               sortedItems.indices.contains(idx) {
                let item = sortedItems[idx]
                let yoy = yoyRows.indices.contains(idx) ? yoyRows[idx].yoy : nil

                let baseMetrics: [ChartPopoverMetric] = series.compactMap { s in
                    s.value(item).map { v in
                        ChartPopoverMetric(
                            id: s.name,
                            label: s.name,
                            value: formatVndCompact(v),
                            color: s.color
                        )
                    }
                }

                let totalMetrics: [ChartPopoverMetric] =
                    series.compactMap { $0.value(item) }
                    .reduceOptionalSum()
                    .map { total in
                        [
                            ChartPopoverMetric(
                                id: "total",
                                label: "Tổng TOI",
                                value: formatVndCompact(total),
                                color: .secondary
                            )
                        ]
                    } ?? []

                let yoyMetrics: [ChartPopoverMetric] = [
                    ChartPopoverMetric(
                        id: "yoy",
                        label: "Tăng trưởng YoY",
                        value: yoy.map { String(format: "%.2f%%", $0) } ?? "—",
                        color: yoyLineColor
                    )
                ]

                let metrics = baseMetrics + totalMetrics + yoyMetrics
                nativeSelectionDetails(title: label, subtitle: "Chi tiết TOI", metrics: metrics)
                    .frame(maxWidth: 280)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }
}

private extension Array where Element == Double {
    func reduceOptionalSum() -> Double? {
        guard !isEmpty else { return nil }
        return self.reduce(0, +)
    }
}

// MARK: - Non-bank: một chỉ tiêu (cột tỷ) + một đường YoY (%, −100…+100)

private enum NonBankMetricYoYKind {
    case revenue
    case profit
}

private struct InteractiveNonBankMetricYoYChart: View {
    let kind: NonBankMetricYoYKind
    let items: [NonBankFinancialDataPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    private struct Row: Identifiable {
        let id: Int
        let year: Int
        let value: Double?
    }

    private struct YoYRow: Identifiable {
        let id: Int
        let year: Int
        let yoy: Double?
    }

    private var rows: [Row] {
        items.sorted { $0.year < $1.year }.map { item in
            let v: Double?
            switch kind {
            case .revenue: v = item.netRevenue
            case .profit: v = item.profitAfterTax
            }
            return Row(id: item.year, year: item.year, value: v)
        }
    }

    private var yoyRows: [YoYRow] {
        var out: [YoYRow] = []
        for i in rows.indices {
            let cur = rows[i]
            var yoy: Double?
            if i > 0 {
                let prev = rows[i - 1]
                if let c = cur.value, let p = prev.value {
                    switch kind {
                    case .revenue:
                        if p > 0 { yoy = (c - p) / p * 100 }
                    case .profit:
                        if p != 0 { yoy = (c - p) / p * 100 }
                    }
                }
            }
            out.append(YoYRow(id: cur.year, year: cur.year, yoy: yoy))
        }
        return out
    }

    /// Trục phải (cột): 0 … max (tỷ).
    private var barDomain: ClosedRange<Double> {
        let vals = rows.compactMap(\.value)
        return unifiedBarDomain(values: vals)
    }

    private var yoyDomain: ClosedRange<Double> {
        return -100 ... 100
    }

    private func clampYoYForPlot(_ pct: Double) -> Double {
        min(max(pct, yoyDomain.lowerBound), yoyDomain.upperBound)
    }

    private func scaleYoYToBarDomain(_ yoy: Double) -> Double {
        let yoyClamped = clampYoYForPlot(yoy)
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = bMax - bMin
        let yMin = yoyDomain.lowerBound
        let ySpan = yoyDomain.upperBound - yMin
        return bMin + ((yoyClamped - yMin) / ySpan) * bSpan
    }

    private var barColor: Color {
        Color.primary.opacity(0.15)
    }

    private var barLegendLabel: String {
        switch kind {
        case .revenue: "Doanh thu"
        case .profit: "LNST"
        }
    }

    private var yoyLineColor: Color {
        switch kind {
        case .revenue: AppColors.chartIncomeInterest
        case .profit: AppColors.chartGrowthStable
        }
    }

    private var yoyLegendLabel: String {
        switch kind {
        case .revenue: "Tăng trưởng DT YoY"
        case .profit: "Tăng trưởng LNST YoY"
        }
    }

    private var popoverSubtitle: String {
        switch kind {
        case .revenue: "Doanh thu & tăng trưởng YoY"
        case .profit: "LNST & tăng trưởng YoY"
        }
    }

    private var labels: [String] {
        rows.indices.map { idx in
            let item = items.sorted { $0.year < $1.year }[idx]
            if showQuarterly && item.quarter != 0 {
                return "Q\(item.quarter) \(item.year % 100)"
            }
            return "\(item.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, rows.count)) : min(4, max(1, rows.count)) }
    private let legendReserved: CGFloat = 52
    private var chartPlotHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""



    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    if let v = row.value {
                        BarMark(
                            x: .value("Kỳ", labels[idx]),
                            y: .value("Giá trị", v)
                        )
                        .foregroundStyle(barColor)
                    }
                }
                
                RuleMark(y: .value("0%", scaleYoYToBarDomain(0)))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    
                ForEach(Array(yoyRows.enumerated()), id: \.offset) { idx, y in
                    if let rv = y.yoy {
                        LineMark(
                            x: .value("Kỳ", labels[idx]),
                            y: .value("YoY", scaleYoYToBarDomain(rv))
                        )
                        .foregroundStyle(yoyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        
                        PointMark(
                            x: .value("Kỳ", labels[idx]),
                            y: .value("YoY", scaleYoYToBarDomain(rv))
                        )
                        .foregroundStyle(yoyLineColor)
                        .symbolSize(36)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartYScale(
                domain: barDomain,
                range: .plotDimension(padding: 0.1)
            )
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatVndCompact(v))
                                .font(AppTypography.caption2)
                                .offset(x: Spacing.xs)
                        }
                    }
                }
                
                AxisMarks(position: .leading, values: [-100.0, -50.0, 0.0, 50.0, 100.0].map { scaleYoYToBarDomain($0) }) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let mappedV = value.as(Double.self) {
                            let ySpan = yoyDomain.upperBound - yoyDomain.lowerBound
                            let bMin = barDomain.lowerBound
                            let bSpan = barDomain.upperBound - bMin
                            let yoy = yoyDomain.lowerBound + ((mappedV - bMin) / bSpan) * ySpan
                            Text("\(Int(round(yoy)))%")
                                .font(AppTypography.caption2)
                                .offset(x: -Spacing.xs)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartPlotHeight)

            HStack(spacing: Spacing.md) {
                chartLegendItem(barLegendLabel, color: barColor)
                chartLegendItem(yoyLegendLabel, color: yoyLineColor)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: legendReserved, alignment: .center)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let idx = labels.firstIndex(of: label), rows.indices.contains(idx) {
                let row = rows[idx]
                let yoy = yoyRows.indices.contains(idx) ? yoyRows[idx].yoy : nil
                nativeSelectionDetails(
                    title: label,
                    subtitle: popoverSubtitle,
                    metrics: popoverMetrics(row: row, yoy: yoy)
                )
                .frame(maxWidth: 280)
                .padding(.top, Spacing.sm)
                .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }

    private func popoverMetrics(row: Row, yoy: Double?) -> [ChartPopoverMetric] {
        var m: [ChartPopoverMetric] = []
        switch kind {
        case .revenue:
            if let v = row.value {
                m.append(ChartPopoverMetric(id: "rev", label: "Doanh thu", value: formatVndCompact(v), color: barColor))
            }
            m.append(
                ChartPopoverMetric(
                    id: "yoy-rev",
                    label: "Tăng trưởng DT YoY",
                    value: yoy.map { String(format: "%.2f%%", $0) } ?? "—",
                    color: yoyLineColor
                )
            )
        case .profit:
            if let v = row.value {
                m.append(ChartPopoverMetric(id: "pat", label: "LNST", value: formatVndCompact(v), color: barColor))
            }
            m.append(
                ChartPopoverMetric(
                    id: "yoy-pat",
                    label: "Tăng trưởng LNST YoY",
                    value: yoy.map { String(format: "%.2f%%", $0) } ?? "—",
                    color: yoyLineColor
                )
            )
        }
        return m
    }
}

// MARK: - Non-bank: biên gộp & ròng (2 đường)

private struct InteractiveNonBankMarginsChart: View {
    let items: [NonBankFinancialDataPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    private struct Row: Identifiable {
        let id: Int
        let year: Int
        let grossMargin: Double?
        let netMargin: Double?
    }

    private var rows: [Row] {
        items.sorted { $0.year < $1.year }.map {
            Row(id: $0.year, year: $0.year, grossMargin: $0.grossMargin, netMargin: $0.netMargin)
        }
    }

    private var labels: [String] {
        rows.indices.map { idx in
            let item = items.sorted { $0.year < $1.year }[idx]
            if showQuarterly && item.quarter != 0 {
                return "Q\(item.quarter) \(item.year % 100)"
            }
            return "\(item.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, rows.count)) : min(4, max(1, rows.count)) }
    private let legendReserved: CGFloat = 52
    private var chartHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private let grossColor = AppColors.chartIncomeFee
    private let netColor = AppColors.chartCapitalEquity

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    if let g = row.grossMargin {
                        LineMark(x: .value("Kỳ", labels[idx]), y: .value("Biên gộp", g))
                            .foregroundStyle(by: .value("Chỉ số", "Biên gộp %"))
                        PointMark(x: .value("Kỳ", labels[idx]), y: .value("Biên gộp", g))
                            .foregroundStyle(by: .value("Chỉ số", "Biên gộp %"))
                    }
                    if let n = row.netMargin {
                        LineMark(x: .value("Kỳ", labels[idx]), y: .value("Biên ròng", n))
                            .foregroundStyle(by: .value("Chỉ số", "Biên ròng %"))
                        PointMark(x: .value("Kỳ", labels[idx]), y: .value("Biên ròng", n))
                            .foregroundStyle(by: .value("Chỉ số", "Biên ròng %"))
                    }
                }
            }
            .chartForegroundStyleScale([
                "Biên gộp %": grossColor,
                "Biên ròng %": netColor,
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(format: "%.0f%%", v))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            HStack(spacing: Spacing.md) {
                chartLegendItem("Biên gộp %", color: grossColor)
                chartLegendItem("Biên ròng %", color: netColor)
            }
            .frame(height: legendReserved, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let idx = labels.firstIndex(of: label), rows.indices.contains(idx) {
                let row = rows[idx]
                let metrics = [
                    row.grossMargin.map { g in
                        ChartPopoverMetric(
                            id: "gross",
                            label: "Biên gộp",
                            value: String(format: "%.2f%%", g),
                            color: grossColor
                        )
                    },
                    row.netMargin.map { n in
                        ChartPopoverMetric(
                            id: "net",
                            label: "Biên ròng",
                            value: String(format: "%.2f%%", n),
                            color: netColor
                        )
                    },
                ].compactMap { $0 }
                nativeSelectionDetails(title: label, subtitle: "Biên LN gộp & ròng", metrics: metrics)
                    .frame(maxWidth: 280)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }
}

private struct InteractiveRoeRoaChart: View {
    let data: [RoeRoaPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool
    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private var labels: [String] {
        data.map { d in
            if showQuarterly && d.quarter != 0 {
                return "Q\(d.quarter) \(d.year % 100)"
            }
            return "\(d.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, data.count)) : min(4, max(1, data.count)) }
    private let legendReserved: CGFloat = 26
    private var chartHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { idx, d in
                    let label = labels[idx]
                    if let roe = d.roe {
                        LineMark(x: .value("Kỳ", label), y: .value("ROE", roe))
                            .foregroundStyle(by: .value("Chỉ số", "ROE"))
                        PointMark(x: .value("Kỳ", label), y: .value("ROE", roe))
                            .foregroundStyle(by: .value("Chỉ số", "ROE"))
                    }
                    if let roa = d.roa {
                        LineMark(x: .value("Kỳ", label), y: .value("ROA", roa))
                            .foregroundStyle(by: .value("Chỉ số", "ROA"))
                        PointMark(x: .value("Kỳ", label), y: .value("ROA", roa))
                            .foregroundStyle(by: .value("Chỉ số", "ROA"))
                    }
                }
            }
            .chartForegroundStyleScale(["ROE": AppColors.chartGrowthStrong, "ROA": AppColors.chartCapitalDeposits])
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartLegend(.hidden)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            HStack(spacing: Spacing.md) {
                chartLegendItem("ROE", color: AppColors.chartGrowthStrong)
                chartLegendItem("ROA", color: AppColors.chartCapitalDeposits)
            }
            .frame(height: legendReserved, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let idx = labels.firstIndex(of: label), data.indices.contains(idx) {
                let item = data[idx]
                let metrics = [
                    item.roe.map { roe in
                        ChartPopoverMetric(
                            id: "roe",
                            label: "ROE",
                            value: String(format: "%.2f%%", roe),
                            color: AppColors.chartGrowthStrong
                        )
                    },
                    item.roa.map { roa in
                        ChartPopoverMetric(
                            id: "roa",
                            label: "ROA",
                            value: String(format: "%.2f%%", roa),
                            color: AppColors.chartCapitalDeposits
                        )
                    },
                ].compactMap { $0 }
                nativeSelectionDetails(title: label, subtitle: "ROE & ROA", metrics: metrics)
                    .frame(maxWidth: 280)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }
}

// MARK: - Non-bank capital structure + net debt / equity line

/// Nợ vay ròng = Vay NH + Vay DH − (Tiền + Đầu tư NH).
/// Đường cam: (Nợ vay ròng / VCSH), trục trái -100% ... 100%.
private struct InteractiveNonBankCapitalStructureChart: View {
    let items: [NonBankFinancialDataPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private struct CapitalStructurePoint {
        let year: Int
        let equityValue: Double
        let shortBorrowValue: Double
        let longBorrowValue: Double
        let advancesValue: Double
        let otherCapitalValue: Double
        let cashValue: Double
        let shortInvestValue: Double
        /// Tổng chiều cao cột (tỷ đồng) — cộng 5 thành phần stack.
        let stackedTotal: Double
        /// Tổng tài sản — cho popover.
        let totalAssetsDisplay: Double?
        let totalLiabilities: Double
        let netDebtValue: Double
        /// nil khi VCSH ≤ 0
        let netDebtToEquityRatio: Double?
    }

    private var legendGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3)
    }

    private var points: [CapitalStructurePoint] {
        items.compactMap(makeCapitalPoint)
    }

    private var labels: [String] {
        points.indices.map { idx in
            let item = items.sorted { $0.year < $1.year }[idx]
            if showQuarterly && item.quarter != 0 {
                return "Q\(item.quarter) \(item.year % 100)"
            }
            return "\(item.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, points.count)) : min(4, max(1, points.count)) }
    private let legendReserved: CGFloat = 176
    private var chartHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }
    /// Cùng mô hình `InteractiveNonBankMetricYoYChart`: **một** thang Y (tỷ, 0…max), trục trái −100%…+100% map tuyến tính lên domain (0% = giữa biểu đồ).
    private var barDomain: ClosedRange<Double> {
        unifiedBarDomain(values: points.map(\.stackedTotal))
    }

    private let leftAxisPctDomain: ClosedRange<Double> = -100 ... 100

    private func scalePctToBarDomain(_ pct: Double) -> Double {
        let pctClamped = min(max(pct, -100), 100)
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = bMax - bMin
        let yMin = leftAxisPctDomain.lowerBound
        let ySpan = leftAxisPctDomain.upperBound - yMin
        return bMin + ((pctClamped - yMin) / ySpan) * bSpan
    }

    private var shouldEnableSelection: Bool { fullScreen }
    private var selectedCapitalPoint: CapitalStructurePoint? {
        guard shouldEnableSelection, let label = displayedLabel, let idx = labels.firstIndex(of: label), points.indices.contains(idx) else { return nil }
        return points[idx]
    }

    var body: some View {
        chartBody
            .frame(height: height, alignment: .top)
            .overlay(alignment: .topTrailing) {
                if fullScreen,
                   let label = displayedLabel,
                   let point = selectedCapitalPoint
                {
                    nativeSelectionDetails(
                        title: label,
                        subtitle: "Chi tiết nguồn vốn",
                        metrics: metrics(for: point)
                    )
                    .frame(maxWidth: 280)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.sm)
                }
            }
            .zIndex(displayedLabel == nil ? 0 : 1)
            .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }

    private var chartBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart(Array(points.enumerated()), id: \.offset) { idx, d in
                let label = labels[idx]
                RuleMark(y: .value("0%", scalePctToBarDomain(0)))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

                BarMark(x: .value("Kỳ", label), y: .value("Vốn CSH", d.equityValue))
                    .foregroundStyle(AppColors.chartCapitalEquity)
                BarMark(x: .value("Kỳ", label), y: .value("Vay NH", d.shortBorrowValue))
                    .foregroundStyle(AppColors.chartCapitalDeposits)
                BarMark(x: .value("Kỳ", label), y: .value("Vay DH", d.longBorrowValue))
                    .foregroundStyle(AppColors.chartCapitalLongTermLoan)
                BarMark(x: .value("Kỳ", label), y: .value("Trả trước KH", d.advancesValue))
                    .foregroundStyle(AppColors.chartCapitalCustomerAdvances)
                BarMark(x: .value("Kỳ", label), y: .value("Nguồn vốn khác", d.otherCapitalValue))
                    .foregroundStyle(AppColors.chartAssetLoans)

                LineMark(
                    x: .value("Kỳ", label),
                    y: .value("Nợ vay ròng/VCSH", lineYValue(for: d))
                )
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                PointMark(
                    x: .value("Kỳ", label),
                    y: .value("Nợ vay ròng/VCSH", lineYValue(for: d))
                )
                .foregroundStyle(Color.orange)
                .symbolSize(34)
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatValueAxisCapital(v))
                                .font(AppTypography.caption2)
                                .offset(x: Spacing.xs)
                        }
                    }
                }

                AxisMarks(
                    position: .leading,
                    values: [-100.0, -50.0, 0.0, 50.0, 100.0].map { scalePctToBarDomain($0) }
                ) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let mappedV = value.as(Double.self) {
                            let ySpan = leftAxisPctDomain.upperBound - leftAxisPctDomain.lowerBound
                            let bMin = barDomain.lowerBound
                            let bSpan = barDomain.upperBound - bMin
                            let pct = leftAxisPctDomain.lowerBound + ((mappedV - bMin) / bSpan) * ySpan
                            Text("\(Int(round(pct)))%")
                                .font(AppTypography.caption2)
                                .offset(x: -Spacing.xs)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                LazyVGrid(columns: legendGridColumns, spacing: Spacing.xs) {
                    chartLegendItem("Vốn CSH", color: AppColors.chartCapitalEquity)
                    chartLegendItem("Vay NH", color: AppColors.chartCapitalDeposits)
                    chartLegendItem("Vay DH", color: AppColors.chartCapitalLongTermLoan)
                    chartLegendItem("Trả trước KH", color: AppColors.chartCapitalCustomerAdvances)
                    chartLegendItem("Nguồn vốn khác", color: AppColors.chartAssetLoans)
                    chartLegendItem("Nợ vay ròng / VCSH", color: .orange)
                }
                Text("Đường cam thể hiện tỷ lệ Nợ vay ròng / VCSH. Trục trái (-100% ... 100%).")
                    .font(AppTypography.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xs)
            }
            .frame(height: legendReserved, alignment: .top)
        }
    }

    private func makeCapitalPoint(_ item: NonBankFinancialDataPoint) -> CapitalStructurePoint? {
        let equity = item.equity ?? 0
        let shortB = item.shortTermBorrowings ?? 0
        let longB = item.longTermBorrowings ?? 0
        let adv = item.advancesFromCustomers ?? 0
        let other = item.otherCapital
        let cash = item.cashAndEquivalents ?? 0
        let stInv = item.shortTermInvestments ?? 0

        let stacked = equity + shortB + longB + adv + other
        guard stacked > 0 else { return nil }

        let totalLiab = item.totalLiabilities ?? (shortB + longB + adv + other)
        let netDebt = (shortB + longB) - (cash + stInv)
        let ratio: Double? = equity != 0 ? netDebt / equity : nil

        return CapitalStructurePoint(
            year: item.year,
            equityValue: equity,
            shortBorrowValue: shortB,
            longBorrowValue: longB,
            advancesValue: adv,
            otherCapitalValue: other,
            cashValue: cash,
            shortInvestValue: stInv,
            stackedTotal: stacked,
            totalAssetsDisplay: item.totalAssets,
            totalLiabilities: totalLiab,
            netDebtValue: netDebt,
            netDebtToEquityRatio: ratio
        )
    }

    private func lineYValue(for point: CapitalStructurePoint) -> Double {
        guard let r = point.netDebtToEquityRatio else { return scalePctToBarDomain(0) }
        let pct = min(max(r * 100, -100), 100)
        return scalePctToBarDomain(pct)
    }

    private func metrics(for point: CapitalStructurePoint) -> [ChartPopoverMetric] {
        var rows: [ChartPopoverMetric] = []
        if let totalAssets = point.totalAssetsDisplay {
            rows.append(
                ChartPopoverMetric(
                    id: "total-assets",
                    label: "Tổng tài sản",
                    value: formatVndCompact(totalAssets),
                    color: AppColors.chartAssetLoans
                )
            )
        }
        rows.append(contentsOf: [
            ChartPopoverMetric(id: "eq", label: "Vốn CSH", value: formatVndCompact(point.equityValue), color: AppColors.chartCapitalEquity),
            ChartPopoverMetric(id: "vay-nh", label: "Vay NH", value: formatVndCompact(point.shortBorrowValue), color: AppColors.chartCapitalDeposits),
            ChartPopoverMetric(id: "vay-dh", label: "Vay DH", value: formatVndCompact(point.longBorrowValue), color: AppColors.chartCapitalLongTermLoan),
            ChartPopoverMetric(id: "adv", label: "Trả trước KH", value: formatVndCompact(point.advancesValue), color: AppColors.chartCapitalCustomerAdvances),
            ChartPopoverMetric(id: "other-cap", label: "Nguồn vốn khác", value: formatVndCompact(point.otherCapitalValue), color: AppColors.chartAssetLoans),
            ChartPopoverMetric(id: "net-debt", label: "Nợ vay ròng", value: formatVndCompact(point.netDebtValue), color: .orange),
            ChartPopoverMetric(id: "liab", label: "Tổng nợ phải trả", value: formatVndCompact(point.totalLiabilities), color: .orange),
        ])
        if let r = point.netDebtToEquityRatio {
            rows.append(
                ChartPopoverMetric(
                    id: "net-de",
                    label: "Nợ vay ròng / VCSH",
                    value: formatRatioVi(r),
                    color: .orange
                )
            )
        } else {
            rows.append(
                ChartPopoverMetric(
                    id: "net-de",
                    label: "Nợ vay ròng / VCSH",
                    value: "— (VCSH ≤ 0)",
                    color: .orange
                )
            )
        }
        return rows
    }

    private func formatValueAxisCapital(_ value: Double) -> String {
        formatVndCompact(value)
    }
}

/// `ratio` là hệ số (vd -0,18); hiển thị **%** (vd -18%) theo locale vi.
private func formatRatioVi(_ ratio: Double) -> String {
    let percent = ratio * 100
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    let num = formatter.string(from: NSNumber(value: percent)) ?? String(format: "%.2f", percent)
    return "\(num)%"
}

private struct InteractiveNonBankAssetQualityChart: View {
    let items: [NonBankFinancialDataPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private struct AssetQualityPoint {
        let year: Int
        let cashValue: Double
        let shortInvestValue: Double
        let shortReceivableValue: Double
        let inventoryValue: Double
        let fixedAssetValue: Double
        let longReceivableValue: Double
        let otherAssetsValue: Double
        let totalAssets: Double
        let receivableRatioPct: Double
    }

    private var points: [AssetQualityPoint] {
        items.compactMap(makeAssetQualityPoint)
    }

    private var labels: [String] {
        points.indices.map { idx in
            let item = items.sorted { $0.year < $1.year }[idx]
            if showQuarterly && item.quarter != 0 {
                return "Q\(item.quarter) \(item.year % 100)"
            }
            return "\(item.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, points.count)) : min(4, max(1, points.count)) }
    private let legendReserved: CGFloat = 148
    private var chartHeight: CGFloat {
        if fullScreen {
            return max(120, height - legendReserved - 48)
        }
        return max(140, height - legendReserved)
    }
    /// Giống chart Doanh thu & YoY: một domain Y (tỷ), trục trái % map tuyến tính −100…+100.
    private var barDomain: ClosedRange<Double> {
        unifiedBarDomain(values: points.map(\.totalAssets))
    }

    private let leftAxisPctDomain: ClosedRange<Double> = -100 ... 100

    private func scalePctToBarDomain(_ pct: Double) -> Double {
        let pctClamped = min(max(pct, -100), 100)
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = bMax - bMin
        let yMin = leftAxisPctDomain.lowerBound
        let ySpan = leftAxisPctDomain.upperBound - yMin
        return bMin + ((pctClamped - yMin) / ySpan) * bSpan
    }

    private var shouldEnableSelection: Bool { fullScreen }
    private var selectedAssetPoint: AssetQualityPoint? {
        guard shouldEnableSelection, let label = displayedLabel, let idx = labels.firstIndex(of: label), points.indices.contains(idx) else { return nil }
        return points[idx]
    }

    var body: some View {
        chartBody
        .frame(height: height, alignment: .top)
        .overlay(alignment: .topTrailing) {
            if fullScreen,
               let label = displayedLabel,
               let point = selectedAssetPoint
            {
                nativeSelectionDetails(
                    title: label,
                    subtitle: "Chi tiết tài sản",
                    metrics: metrics(for: point)
                )
                .frame(maxWidth: 280)
                .padding(.top, Spacing.sm)
                .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }

    private var chartBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart(Array(points.enumerated()), id: \.offset) { idx, d in
                let label = labels[idx]
                RuleMark(y: .value("0%", scalePctToBarDomain(0)))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

                BarMark(x: .value("Kỳ", label), y: .value("Tiền", d.cashValue))
                    .foregroundStyle(AppColors.chartAssetCash)
                BarMark(x: .value("Kỳ", label), y: .value("Đầu tư ngắn hạn", d.shortInvestValue))
                    .foregroundStyle(AppColors.chartCapitalDeposits)
                BarMark(x: .value("Kỳ", label), y: .value("Phải thu ngắn hạn", d.shortReceivableValue))
                    .foregroundStyle(AppColors.chartAssetTrading)
                BarMark(x: .value("Kỳ", label), y: .value("Hàng tồn kho", d.inventoryValue))
                    .foregroundStyle(AppColors.chartInventory)
                BarMark(x: .value("Kỳ", label), y: .value("Tài sản cố định", d.fixedAssetValue))
                    .foregroundStyle(AppColors.chartGrowthStrong)
                BarMark(x: .value("Kỳ", label), y: .value("Phải thu dài hạn", d.longReceivableValue))
                    .foregroundStyle(AppColors.chartIncomeOther)
                BarMark(x: .value("Kỳ", label), y: .value("Tài sản khác", d.otherAssetsValue))
                    .foregroundStyle(AppColors.chartAssetLoans)

                LineMark(
                    x: .value("Kỳ", label),
                    y: .value("Tỷ lệ phải thu trên tổng tài sản", lineYValue(for: d))
                )
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                PointMark(
                    x: .value("Kỳ", label),
                    y: .value("Tỷ lệ phải thu trên tổng tài sản", lineYValue(for: d))
                )
                .foregroundStyle(Color.orange)
                .symbolSize(34)
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatValueAxis(v))
                                .font(AppTypography.caption2)
                                .offset(x: Spacing.xs)
                        }
                    }
                }

                AxisMarks(
                    position: .leading,
                    values: [-100.0, -50.0, 0.0, 50.0, 100.0].map { scalePctToBarDomain($0) }
                ) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let mappedV = value.as(Double.self) {
                            let ySpan = leftAxisPctDomain.upperBound - leftAxisPctDomain.lowerBound
                            let bMin = barDomain.lowerBound
                            let bSpan = barDomain.upperBound - bMin
                            let pct = leftAxisPctDomain.lowerBound + ((mappedV - bMin) / bSpan) * ySpan
                            Text("\(Int(round(pct)))%")
                                .font(AppTypography.caption2)
                                .offset(x: -Spacing.xs)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    chartLegendItem("Tiền", color: AppColors.chartAssetCash).frame(maxWidth: .infinity, alignment: .leading)
                    chartLegendItem("Đầu tư ngắn hạn", color: AppColors.chartCapitalDeposits).frame(maxWidth: .infinity, alignment: .leading)
                    chartLegendItem("Phải thu ngắn hạn", color: AppColors.chartAssetTrading).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .top, spacing: Spacing.xs) {
                    chartLegendItem("Hàng tồn kho", color: AppColors.chartInventory).frame(maxWidth: .infinity, alignment: .leading)
                    chartLegendItem("Tài sản cố định", color: AppColors.chartGrowthStrong).frame(maxWidth: .infinity, alignment: .leading)
                    chartLegendItem("Phải thu dài hạn", color: AppColors.chartIncomeOther).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .top, spacing: Spacing.xs) {
                    chartLegendItem("Tài sản khác", color: AppColors.chartAssetLoans).frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0).frame(maxWidth: .infinity)
                    Spacer(minLength: 0).frame(maxWidth: .infinity)
                }
                HStack(alignment: .top, spacing: Spacing.xs) {
                    chartLegendItem("Tỷ lệ phải thu / tổng tài sản", color: .orange).frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0).frame(maxWidth: .infinity)
                    Spacer(minLength: 0).frame(maxWidth: .infinity)
                }
            }
            .frame(height: legendReserved, alignment: .top)
        }
    }
    private func makeAssetQualityPoint(_ item: NonBankFinancialDataPoint) -> AssetQualityPoint? {
        let cash = item.cashAndEquivalents ?? 0
        let shortInvest = item.shortTermInvestments ?? 0
        let shortRec = item.shortTermReceivables ?? 0
        let inventory = item.inventories ?? 0
        let fixedAsset = item.fixedAssets ?? 0
        let longRec = item.longTermReceivables ?? 0
        let other = item.otherAssets
        let denom = item.totalAssets ?? item.knownAssetComponentsSum ?? 0
        guard denom > 0 else { return nil }

        return AssetQualityPoint(
            year: item.year,
            cashValue: cash,
            shortInvestValue: shortInvest,
            shortReceivableValue: shortRec,
            inventoryValue: inventory,
            fixedAssetValue: fixedAsset,
            longReceivableValue: longRec,
            otherAssetsValue: other,
            totalAssets: denom,
            receivableRatioPct: ((shortRec + longRec) / denom) * 100
        )
    }
    private func metrics(for point: AssetQualityPoint) -> [ChartPopoverMetric] {
        [
            ChartPopoverMetric(id: "total-assets", label: "Tổng tài sản", value: formatVndCompact(point.totalAssets), color: AppColors.chartAssetLoans),
            ChartPopoverMetric(id: "cash", label: "Tiền", value: formatVndCompact(point.cashValue), color: AppColors.chartAssetCash),
            ChartPopoverMetric(id: "short-invest", label: "Đầu tư ngắn hạn", value: formatVndCompact(point.shortInvestValue), color: AppColors.chartCapitalDeposits),
            ChartPopoverMetric(id: "short-rec", label: "Phải thu ngắn hạn", value: formatVndCompact(point.shortReceivableValue), color: AppColors.chartAssetTrading),
            ChartPopoverMetric(id: "inv", label: "Hàng tồn kho", value: formatVndCompact(point.inventoryValue), color: AppColors.chartInventory),
            ChartPopoverMetric(id: "fixed", label: "Tài sản cố định", value: formatVndCompact(point.fixedAssetValue), color: AppColors.chartGrowthStrong),
            ChartPopoverMetric(id: "long-rec", label: "Phải thu dài hạn", value: formatVndCompact(point.longReceivableValue), color: AppColors.chartIncomeOther),
            ChartPopoverMetric(id: "other-assets", label: "Tài sản khác", value: formatVndCompact(point.otherAssetsValue), color: AppColors.chartAssetLoans),
            ChartPopoverMetric(id: "rec-ratio", label: "Tỷ lệ phải thu trên tổng tài sản", value: String(format: "%.1f%%", point.receivableRatioPct), color: .orange),
        ]
    }
    private func lineYValue(for point: AssetQualityPoint) -> Double {
        let pct = min(max(point.receivableRatioPct, -100), 100)
        return scalePctToBarDomain(pct)
    }

    private func formatValueAxis(_ value: Double) -> String {
        formatVndCompact(value)
    }
}

private func formatVndCompact(_ value: Double) -> String {
    // Backend returns VND (dong). Force one display unit: billion VND.
    let billion = value / 1_000_000_000
    let absBillion = abs(billion)
    let fractionDigits: Int
    if absBillion >= 100 {
        fractionDigits = 0
    } else if absBillion >= 10 {
        fractionDigits = 1
    } else {
        fractionDigits = 2
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits

    let number = formatter.string(from: NSNumber(value: billion)) ?? String(format: "%.\(fractionDigits)f", billion)
    return "\(number) tỷ"
}

private func chartLegendItem(_ title: String, color: Color) -> some View {
    HStack(spacing: Spacing.xs) {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
        Text(title).font(AppTypography.caption2).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
    }
}

private func nativeSelectionDetails(title: String, subtitle: String, metrics: [ChartPopoverMetric]) -> some View {
    return VStack(alignment: .leading, spacing: Spacing.xs) {
        Text(title)
            .font(AppTypography.caption)
            .fontWeight(.semibold)
        Text(subtitle)
            .font(AppTypography.caption2)
            .foregroundStyle(.secondary)
        ForEach(metrics, id: \.id) { metric in
            nativeSelectionMetricRow(metric)
        }
    }
    .padding(Spacing.sm)
    .background(AppColors.appBackground)
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
}

private func nativeSelectionMetricRow(_ metric: ChartPopoverMetric) -> some View {
    HStack(spacing: Spacing.xs) {
        Circle()
            .fill(metric.color)
            .frame(width: 6, height: 6)
        Text(metric.label)
            .font(AppTypography.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        Spacer(minLength: 0)
        Text(metric.value)
            .font(AppTypography.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
    }
}

// MARK: - Bank: Bức tranh NIM

private struct InteractiveBankNimChart: View {
    let items: [BankFinancialDataPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    /// Thứ tự khớp backend: (year, quarter) tăng dần.
    private var sortedItems: [BankFinancialDataPoint] { items }

    private var labels: [String] {
        sortedItems.map { item in
            if showQuarterly && item.quarter != 0 {
                return "Q\(item.quarter) \(item.year % 100)"
            }
            return "\(item.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, items.count)) : min(4, max(1, items.count)) }
    private let legendReserved: CGFloat = 52
    private var chartPlotHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    private let bgBarColor = Color.primary.opacity(0.15)
    private let fgBarColor = Color.red
    private let lineLineColor = AppColors.chartGrowthStrong

    private func grossInterest(for item: BankFinancialDataPoint) -> Double {
        let net = item.netInterestIncome ?? 0
        let exp = abs(item.interestExpense ?? 0)
        return net + exp
    }

    private func nim(for item: BankFinancialDataPoint) -> Double? {
        guard let ta = item.totalAssets, ta > 0 else { return nil }
        let net = item.netInterestIncome ?? 0
        // Dữ liệu lợi nhuận đang là 1 Quý, cần Annualized (X4) để tính NIM TTM tương đương
        return ((net * 4.0) / ta) * 100
    }

    private var barDomain: ClosedRange<Double> {
        let vals = sortedItems.map { grossInterest(for: $0) }
        return unifiedBarDomain(values: vals)
    }

    private var lineDomain: ClosedRange<Double> {
        // Y-axis cho % NIM (xử lý giống chart YoY nhưng giới hạn để dễ đọc).
        // Yêu cầu: đỉnh 15%, đáy -15%.
        return -15 ... 15
    }

    private func clampLineForPlot(_ v: Double) -> Double {
        min(max(v, lineDomain.lowerBound), lineDomain.upperBound)
    }

    private func scaleLineToBarDomain(_ val: Double) -> Double {
        let clamped = clampLineForPlot(val)
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = bMax - bMin
        let lMin = lineDomain.lowerBound
        let lSpan = lineDomain.upperBound - lMin
        guard lSpan > 0 else { return bMin }
        return bMin + ((clamped - lMin) / lSpan) * bSpan
    }

    private func scaleBarDomainToLine(_ mappedY: Double) -> Double {
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = max(bMax - bMin, 1e-9)
        let lMin = lineDomain.lowerBound
        let lSpan = lineDomain.upperBound - lMin
        return lMin + ((mappedY - bMin) / bSpan) * lSpan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                ForEach(Array(sortedItems.enumerated()), id: \.offset) { idx, item in
                    let label = labels[idx]
                    let gross = grossInterest(for: item)
                    let exp = abs(item.interestExpense ?? 0)

                    // Background Bar: Gross Interest
                    BarMark(
                        x: .value("Kỳ", label),
                        y: .value("Tổng thu lãi", gross)
                    )
                    .foregroundStyle(bgBarColor)

                    // Foreground Bar: Interest Expense overlays
                    BarMark(
                        x: .value("Kỳ", label),
                        y: .value("Chi phí lãi", exp)
                    )
                    .foregroundStyle(fgBarColor)

                    // Line: NIM
                    if let n = nim(for: item) {
                        let scaled = scaleLineToBarDomain(n)
                        LineMark(
                            x: .value("Kỳ", label),
                            y: .value("NIM", scaled)
                        )
                        .foregroundStyle(lineLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Kỳ", label),
                            y: .value("NIM", scaled)
                        )
                        .foregroundStyle(lineLineColor)
                        .symbolSize(36)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatVndCompact(v))
                                .font(AppTypography.caption2)
                                .offset(x: Spacing.xs)
                        }
                    }
                }
                
                AxisMarks(
                    position: .leading,
                    values: [-15.0, -7.5, 0.0, 7.5, 15.0].map { scaleLineToBarDomain($0) }
                ) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let mappedV = value.as(Double.self) {
                            let pct = scaleBarDomainToLine(mappedV)
                            Text("\(Int(round(pct)))%")
                                .font(AppTypography.caption2)
                                .offset(x: -Spacing.xs)
                        }
                    }
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartPlotHeight)

            let cols = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3)
            LazyVGrid(columns: cols, spacing: Spacing.xs) {
                chartLegendItem("Tổng thu lãi", color: bgBarColor)
                chartLegendItem("Chi phí lãi", color: fgBarColor)
                chartLegendItem("NIM ước tính", color: lineLineColor)
            }
            .frame(minHeight: legendReserved, alignment: .top)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let idx = labels.firstIndex(of: label), sortedItems.indices.contains(idx) {
                let item = sortedItems[idx]
                
                let gross = grossInterest(for: item)
                let exp = abs(item.interestExpense ?? 0)
                let net = item.netInterestIncome ?? 0
                
                let nimMetric = nim(for: item).map { n in
                    ChartPopoverMetric(id: "nim", label: "NIM (Ước tính TTM)", value: String(format: "%.2f%%", n), color: lineLineColor)
                }
                
                let mt: [ChartPopoverMetric] = [
                    ChartPopoverMetric(id: "gross", label: "Tổng thu lãi", value: formatVndCompact(gross), color: bgBarColor),
                    ChartPopoverMetric(id: "exp", label: "Chi phí lãi", value: formatVndCompact(exp), color: fgBarColor),
                    ChartPopoverMetric(id: "net", label: "Lãi thuần", value: formatVndCompact(net), color: AppColors.chartIncomeInterest)
                ] + (nimMetric.map { [$0] } ?? [])
                nativeSelectionDetails(title: label, subtitle: "Biên lãi thuần", metrics: mt)
                    .frame(maxWidth: 280)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear { hidePopoverTask?.cancel(); hidePopoverTask = nil }
    }
}


