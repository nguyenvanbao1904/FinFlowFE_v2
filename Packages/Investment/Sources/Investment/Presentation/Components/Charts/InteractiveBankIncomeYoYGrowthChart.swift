import Charts
import FinFlowCore
import SwiftUI

struct InteractiveBankIncomeYoYGrowthChart: View {
    let items: [BankFinancialDataPoint]
    let series: [(name: String, color: Color, value: (BankFinancialDataPoint) -> Double?)]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    private let yoyLineColor: Color = AppColors.chartGrowthStrong
    private let legendReserved: CGFloat = 52

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
            SeriesItem(id: offset, name: element.name, color: element.color, value: element.value)
        }
    }

    private struct YoYPlotPoint: Identifiable {
        let id: Int
        let rowIndex: Int
        let year: Int
        let scaled: Double
    }

    private var yoyPlotPoints: [YoYPlotPoint] {
        yoyRows.enumerated().compactMap { i, y in
            guard let rv = y.yoy else { return nil }
            return YoYPlotPoint(id: y.id, rowIndex: i, year: y.year, scaled: scaleYoYToBarDomain(rv))
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
        rows.indices.map { i in
            let cur = rows[i]
            let item = sortedItems[i]
            return YoYRow(id: cur.id, year: cur.year, yoy: item.yoyTotalOperatingIncome)
        }
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
        InteractiveChartScaffold(
            labels: labels,
            height: height,
            fullScreen: fullScreen,
            legendReserved: legendReserved,
            popoverBuilder: { _, idx in
                guard rows.indices.contains(idx), sortedItems.indices.contains(idx) else { return nil }
                let item = sortedItems[idx]
                let yoy = yoyRows.indices.contains(idx) ? yoyRows[idx].yoy : nil

                let baseMetrics: [ChartPopoverMetric] = series.compactMap { s in
                    s.value(item).map { v in
                        ChartPopoverMetric(id: s.name, label: s.name, value: formatVndCompact(v), color: s.color)
                    }
                }

                let totalMetrics: [ChartPopoverMetric] =
                    series.compactMap { $0.value(item) }
                        .reduceOptionalSum()
                        .map { total in
                            [ChartPopoverMetric(id: "total", label: "Tổng TOI", value: formatVndCompact(total), color: .secondary)]
                        } ?? []

                let yoyMetrics = [
                    ChartPopoverMetric(
                        id: "yoy", label: "Tăng trưởng YoY",
                        value: yoy.map { String(format: "%.2f%%", $0) } ?? "—",
                        color: yoyLineColor
                    )
                ]

                return baseMetrics + totalMetrics + yoyMetrics
            },
            popoverSubtitle: "Chi tiết TOI",
            legend: {
                let columnsCount = min(legendItems.count, 3)
                let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: columnsCount)
                LazyVGrid(columns: columns, spacing: Spacing.xs) {
                    ForEach(Array(legendItems.enumerated()), id: \.offset) { _, it in
                        chartLegendItem(it.0, color: it.1)
                    }
                }
            }
        ) { scrollLabel, selectedLabel, chartHeight in
            Chart {
                ForEach(Array(sortedItems.enumerated()), id: \.offset) { idx, item in
                    let label = labels[idx]
                    ForEach(seriesItems) { s in
                        if let v = s.value(item) {
                            BarMark(x: .value("Kỳ", label), y: .value(s.name, v))
                                .foregroundStyle(s.color)
                        }
                    }
                }

                RuleMark(y: .value("0%", zeroYoYMapped))
                    .foregroundStyle(Color.primary.opacity(OpacityLevel.high))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

                ForEach(yoyPlotPoints) { p in
                    let label = labels.indices.contains(p.rowIndex) ? labels[p.rowIndex] : String(p.year)
                    LineMark(x: .value("Kỳ", label), y: .value("YoY", p.scaled))
                        .foregroundStyle(yoyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Kỳ", label), y: .value("YoY", p.scaled))
                        .foregroundStyle(yoyLineColor)
                        .symbolSize(36)
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

                AxisMarks(position: .leading, values: yoyAxisValues) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(OpacityLevel.chartGrid))
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
            .interactiveChartModifiers(
                scrollLabel: scrollLabel,
                selectedLabel: selectedLabel,
                visibleLength: fullScreen ? min(8, max(1, rows.count)) : min(4, max(1, rows.count)),
                fullScreen: fullScreen,
                chartHeight: chartHeight
            )
        }
    }
}

private extension Array where Element == Double {
    func reduceOptionalSum() -> Double? {
        guard !isEmpty else { return nil }
        return self.reduce(0, +)
    }
}
