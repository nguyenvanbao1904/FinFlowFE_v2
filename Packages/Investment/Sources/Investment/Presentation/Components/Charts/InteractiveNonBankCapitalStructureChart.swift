import Charts
import FinFlowCore
import SwiftUI

/// Nợ vay ròng = Vay NH + Vay DH − (Tiền + Đầu tư NH).
/// Đường cam: (Nợ vay ròng / VCSH), trục trái -100% ... 100%.
struct InteractiveNonBankCapitalStructureChart: View {
    let items: [NonBankFinancialDataPoint]
    let height: CGFloat
    let fullScreen: Bool

    private struct CapitalStructurePoint {
        let periodLabel: String
        let year: Int
        let equityValue: Double
        let shortBorrowValue: Double
        let longBorrowValue: Double
        let advancesValue: Double
        let otherCapitalValue: Double
        let cashValue: Double
        let shortInvestValue: Double
        let stackedTotal: Double
        let totalAssetsDisplay: Double?
        let totalLiabilities: Double
        let netDebtValue: Double
        let netDebtToEquityRatio: Double?
    }

    private var legendGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3)
    }

    private var points: [CapitalStructurePoint] {
        items
            .sorted { a, b in
                if a.year != b.year { return a.year < b.year }
                return a.quarter < b.quarter
            }
            .compactMap(makeCapitalPoint)
    }

    private var labels: [String] { points.map(\.periodLabel) }

    private var legendGridReserved: CGFloat { 52 }

    private var footnoteReserved: CGFloat { Spacing.xs + 36 }
    private var legendReserved: CGFloat { legendGridReserved + footnoteReserved }

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

    var body: some View {
        InteractiveChartScaffold(
            labels: labels,
            height: height,
            fullScreen: fullScreen,
            legendReserved: legendReserved,
            popoverBuilder: { _, idx in
                guard points.indices.contains(idx) else { return nil }
                return metrics(for: points[idx])
            },
            popoverSubtitle: "Chi tiết nguồn vốn",
            legend: {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    LazyVGrid(columns: legendGridColumns, spacing: Spacing.xs) {
                        chartLegendItem("Vốn CSH", color: AppColors.chartCapitalEquity)
                        chartLegendItem("Vay NH", color: AppColors.chartCapitalDeposits)
                        chartLegendItem("Vay DH", color: AppColors.chartCapitalLongTermLoan)
                        chartLegendItem("Trả trước KH", color: AppColors.chartCapitalCustomerAdvances)
                        chartLegendItem("Nguồn vốn khác", color: AppColors.chartAssetLoans)
                        chartLegendItem("Nợ vay ròng / VCSH", color: AppColors.chartRatioLine)
                    }
                    .frame(height: legendGridReserved, alignment: .top)
                    Text("Đường cam: Nợ vay ròng / VCSH · Trục trái −100% … 100%.")
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
        ) { scrollLabel, selectedLabel, chartHeight in
            Chart(Array(points.enumerated()), id: \.offset) { idx, d in
                let label = labels[idx]

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

                LineMark(x: .value("Kỳ", label), y: .value("Nợ vay ròng/VCSH", lineYValue(for: d)))
                    .foregroundStyle(AppColors.chartRatioLine)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Kỳ", label), y: .value("Nợ vay ròng/VCSH", lineYValue(for: d)))
                    .foregroundStyle(AppColors.chartRatioLine)
                    .symbolSize(30)
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(OpacityLevel.chartGrid))
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
                    values: [-100.0, -50.0, 0.0, 50.0, 100.0].map { scalePctToBarDomain($0) }
                ) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(OpacityLevel.chartGrid))
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
            .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
            .interactiveChartModifiers(
                scrollLabel: scrollLabel,
                selectedLabel: selectedLabel,
                visibleLength: fullScreen ? min(8, max(1, points.count)) : min(4, max(1, points.count)),
                fullScreen: fullScreen,
                chartHeight: chartHeight
            )
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
            periodLabel: item.periodLabel,
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
            rows.append(ChartPopoverMetric(id: "total-assets", label: "Tổng tài sản", value: formatVndCompact(totalAssets), color: AppColors.chartAssetLoans))
        }
        rows.append(contentsOf: [
            ChartPopoverMetric(id: "eq", label: "Vốn CSH", value: formatVndCompact(point.equityValue), color: AppColors.chartCapitalEquity),
            ChartPopoverMetric(id: "vay-nh", label: "Vay NH", value: formatVndCompact(point.shortBorrowValue), color: AppColors.chartCapitalDeposits),
            ChartPopoverMetric(id: "vay-dh", label: "Vay DH", value: formatVndCompact(point.longBorrowValue), color: AppColors.chartCapitalLongTermLoan),
            ChartPopoverMetric(id: "adv", label: "Trả trước KH", value: formatVndCompact(point.advancesValue), color: AppColors.chartCapitalCustomerAdvances),
            ChartPopoverMetric(id: "other-cap", label: "Nguồn vốn khác", value: formatVndCompact(point.otherCapitalValue), color: AppColors.chartAssetLoans),
            ChartPopoverMetric(id: "net-debt", label: "Nợ vay ròng", value: formatVndCompact(point.netDebtValue), color: AppColors.chartRatioLine),
            ChartPopoverMetric(id: "liab", label: "Tổng nợ phải trả", value: formatVndCompact(point.totalLiabilities), color: AppColors.chartRatioLine)
        ])
        if let r = point.netDebtToEquityRatio {
            rows.append(ChartPopoverMetric(id: "net-de", label: "Nợ vay ròng / VCSH", value: formatRatioVi(r), color: AppColors.chartRatioLine))
        } else {
            rows.append(ChartPopoverMetric(id: "net-de", label: "Nợ vay ròng / VCSH", value: "— (VCSH ≤ 0)", color: AppColors.chartRatioLine))
        }
        return rows
    }
}
