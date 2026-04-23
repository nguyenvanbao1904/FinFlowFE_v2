import Charts
import FinFlowCore
import SwiftUI

// MARK: - Bank: Bức tranh NIM

struct InteractiveBankNimChart: View {
    let items: [BankFinancialDataPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    /// Thứ tự khớp backend: (year, quarter) tăng dần.
    private var sortedItems: [BankFinancialDataPoint] { items }

    private var labels: [String] { sortedItems.map(\.periodLabel) }
    private let legendReserved: CGFloat = 52

    private let bgBarColor = Color.primary.opacity(0.15)
    private let fgBarColor = AppColors.chartNimExpense
    private let lineLineColor = AppColors.chartGrowthStrong

    private func grossInterest(for item: BankFinancialDataPoint) -> Double {
        let net = item.netInterestIncome ?? 0
        let exp = abs(item.interestExpense ?? 0)
        return net + exp
    }

    private func nim(for item: BankFinancialDataPoint) -> Double? {
        guard let ta = item.totalAssets, ta > 0 else { return nil }
        let net = item.netInterestIncome ?? 0
        let annualizedNet = item.quarter == 0 ? net : net * 4.0
        return (annualizedNet / ta) * 100
    }

    private var barDomain: ClosedRange<Double> {
        let vals = sortedItems.map { grossInterest(for: $0) }
        return unifiedBarDomain(values: vals)
    }

    private var lineDomain: ClosedRange<Double> { -15 ... 15 }

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
        InteractiveChartScaffold(
            labels: labels,
            height: height,
            fullScreen: fullScreen,
            legendReserved: legendReserved,
            popoverBuilder: { _, idx in
                guard sortedItems.indices.contains(idx) else { return nil }
                let item = sortedItems[idx]
                let gross = grossInterest(for: item)
                let exp = abs(item.interestExpense ?? 0)
                let net = item.netInterestIncome ?? 0

                let nimMetric = nim(for: item).map { n in
                    ChartPopoverMetric(
                        id: "nim",
                        label: item.quarter == 0 ? "NIM (ước tính)" : "NIM (ước tính TTM)",
                        value: String(format: "%.2f%%", n),
                        color: lineLineColor
                    )
                }

                return [
                    ChartPopoverMetric(id: "gross", label: "Tổng thu lãi", value: formatVndCompact(gross), color: bgBarColor),
                    ChartPopoverMetric(id: "exp", label: "Chi phí lãi", value: formatVndCompact(exp), color: fgBarColor),
                    ChartPopoverMetric(id: "net", label: "Lãi thuần", value: formatVndCompact(net), color: AppColors.chartIncomeInterest),
                ] + (nimMetric.map { [$0] } ?? [])
            },
            popoverSubtitle: "Biên lãi thuần",
            legend: {
                let cols = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3)
                LazyVGrid(columns: cols, spacing: Spacing.xs) {
                    chartLegendItem("Tổng thu lãi", color: bgBarColor)
                    chartLegendItem("Chi phí lãi", color: fgBarColor)
                    chartLegendItem("NIM ước tính", color: lineLineColor)
                }
            }
        ) { scrollLabel, selectedLabel, chartHeight in
            Chart {
                ForEach(sortedItems) { item in
                    let label = item.periodLabel
                    let gross = grossInterest(for: item)
                    let exp = abs(item.interestExpense ?? 0)

                    BarMark(x: .value("Kỳ", label), y: .value("Tổng thu lãi", gross))
                        .foregroundStyle(bgBarColor)
                    BarMark(x: .value("Kỳ", label), y: .value("Chi phí lãi", exp))
                        .foregroundStyle(fgBarColor)

                    if let n = nim(for: item) {
                        let scaled = scaleLineToBarDomain(n)
                        LineMark(x: .value("Kỳ", label), y: .value("NIM", scaled))
                            .foregroundStyle(lineLineColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("Kỳ", label), y: .value("NIM", scaled))
                            .foregroundStyle(lineLineColor)
                            .symbolSize(36)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
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
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(OpacityLevel.chartGrid))
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
            .interactiveChartModifiers(
                scrollLabel: scrollLabel,
                selectedLabel: selectedLabel,
                visibleLength: fullScreen ? min(8, max(1, items.count)) : min(4, max(1, items.count)),
                fullScreen: fullScreen,
                chartHeight: chartHeight
            )
        }
    }
}
