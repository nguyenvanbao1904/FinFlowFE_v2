import Charts
import FinFlowCore
import SwiftUI

struct InteractiveNonBankAssetQualityChart: View {
    let items: [NonBankFinancialDataPoint]
    let height: CGFloat
    let fullScreen: Bool

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private struct AssetQualityPoint {
        let periodLabel: String
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

    private var legendGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3)
    }

    private var points: [AssetQualityPoint] {
        items
            .sorted { a, b in
                if a.year != b.year { return a.year < b.year }
                return a.quarter < b.quarter
            }
            .compactMap(makeAssetQualityPoint)
    }

    private var labels: [String] { points.map(\.periodLabel) }

    private var visibleLength: Int { fullScreen ? min(8, max(1, points.count)) : min(4, max(1, points.count)) }

    private var legendGridReserved: CGFloat {
        let legendItemCount = 8
        if legendItemCount <= 3 { return 26 }
        if legendItemCount <= 6 { return 52 }
        return 78
    }

    private var footnoteReserved: CGFloat { Spacing.xs + 36 }

    private var legendReserved: CGFloat { legendGridReserved + footnoteReserved }

    private var chartHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    /// Giống chart Doanh thu & YoY: một domain Y (tỷ), trục trái % map tuyến tính 0…100.
    private var barDomain: ClosedRange<Double> {
        unifiedBarDomain(values: points.map(\.totalAssets))
    }

    private let leftAxisPctDomain: ClosedRange<Double> = 0 ... 100

    private func scalePctToBarDomain(_ pct: Double) -> Double {
        let pctClamped = min(max(pct, 0), 100)
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = bMax - bMin
        let yMin = leftAxisPctDomain.lowerBound
        let ySpan = leftAxisPctDomain.upperBound - yMin
        return bMin + ((pctClamped - yMin) / ySpan) * bSpan
    }

    private var shouldEnableSelection: Bool { fullScreen }
    private var selectedAssetPoint: AssetQualityPoint? {
        guard shouldEnableSelection,
            let label = displayedLabel,
            let idx = labels.firstIndex(of: label),
            points.indices.contains(idx)
        else { return nil }
        return points[idx]
    }

    var body: some View {
        chartBody
            .frame(height: height, alignment: .top)
            .overlay(alignment: .topTrailing) {
                if fullScreen, let label = displayedLabel, let point = selectedAssetPoint {
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
            .onDisappear {
                hidePopoverTask?.cancel()
                hidePopoverTask = nil
            }
    }

    private var chartBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart(Array(points.enumerated()), id: \.offset) { idx, d in
                let label = labels[idx]

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
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Kỳ", label),
                    y: .value("Tỷ lệ phải thu trên tổng tài sản", lineYValue(for: d))
                )
                .foregroundStyle(Color.orange)
                .symbolSize(30)
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
                    values: [0.0, 25.0, 50.0, 75.0, 100.0].map { scalePctToBarDomain($0) }
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
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) {
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
                    chartLegendItem("Tiền", color: AppColors.chartAssetCash)
                    chartLegendItem("Đầu tư ngắn hạn", color: AppColors.chartCapitalDeposits)
                    chartLegendItem("Phải thu ngắn hạn", color: AppColors.chartAssetTrading)
                    chartLegendItem("Hàng tồn kho", color: AppColors.chartInventory)
                    chartLegendItem("Tài sản cố định", color: AppColors.chartGrowthStrong)
                    chartLegendItem("Phải thu dài hạn", color: AppColors.chartIncomeOther)
                    chartLegendItem("Tài sản khác", color: AppColors.chartAssetLoans)
                    chartLegendItem("Phải thu / tổng TS", color: .orange)
                }
                .frame(height: legendGridReserved, alignment: .top)
                Text("Đường cam: phải thu / tổng tài sản · Trục trái 0 … 100%.")
                    .font(AppTypography.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
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
            periodLabel: item.periodLabel,
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
        let pct = min(max(point.receivableRatioPct, 0), 100)
        return scalePctToBarDomain(pct)
    }

    private func formatValueAxis(_ value: Double) -> String {
        formatVndCompact(value)
    }
}
