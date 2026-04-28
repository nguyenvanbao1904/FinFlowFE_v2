import Charts
import FinFlowCore
import SwiftUI

/// Generic single-bar + YoY line chart.
/// Replaces InteractiveBankProfitYoYGrowthChart and InteractiveNonBankMetricYoYChart.
struct InteractiveSingleBarYoYChart: View {
    let rows: [BarYoYRow]
    let barColor: Color
    let barLabel: String
    let yoyLineColor: Color
    let yoyLabel: String
    let popoverSubtitle: String
    let height: CGFloat
    let fullScreen: Bool

    struct BarYoYRow: Identifiable {
        let id: String
        let periodLabel: String
        let value: Double?
        let yoy: Double?
    }

    private var labels: [String] { rows.map(\.periodLabel) }
    private let legendReserved: CGFloat = 52

    private var barDomain: ClosedRange<Double> {
        unifiedBarDomain(values: rows.compactMap(\.value))
    }

    private let yoyDomain: ClosedRange<Double> = -100...100

    // MARK: - YoY ↔ Bar domain scaling

    private func scaleYoY(_ yoy: Double) -> Double {
        let clamped = min(max(yoy, yoyDomain.lowerBound), yoyDomain.upperBound)
        let bMin = barDomain.lowerBound
        let bSpan = barDomain.upperBound - bMin
        let ySpan = yoyDomain.upperBound - yoyDomain.lowerBound
        return bMin + ((clamped - yoyDomain.lowerBound) / ySpan) * bSpan
    }

    private func unscaleYoY(_ mapped: Double) -> Double {
        let bMin = barDomain.lowerBound
        let bSpan = max(barDomain.upperBound - bMin, 1e-9)
        let ySpan = yoyDomain.upperBound - yoyDomain.lowerBound
        return yoyDomain.lowerBound + ((mapped - bMin) / bSpan) * ySpan
    }

    var body: some View {
        InteractiveChartScaffold(
            labels: labels,
            height: height,
            fullScreen: fullScreen,
            legendReserved: legendReserved,
            popoverBuilder: { _, idx in
                guard rows.indices.contains(idx) else { return nil }
                let row = rows[idx]
                return makeMetrics(row: row)
            },
            popoverSubtitle: popoverSubtitle,
            legend: {
                HStack(spacing: Spacing.md) {
                    chartLegendItem(barLabel, color: barColor)
                    chartLegendItem(yoyLabel, color: yoyLineColor)
                }
            }
        ) { scrollLabel, selectedLabel, chartHeight in
            Chart {
                ForEach(rows) { row in
                    if let v = row.value {
                        BarMark(x: .value("Kỳ", row.periodLabel), y: .value("Giá trị", v))
                            .foregroundStyle(barColor)
                    }
                }

                RuleMark(y: .value("0%", scaleYoY(0)))
                    .foregroundStyle(Color.primary.opacity(OpacityLevel.high))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

                ForEach(rows) { r in
                    if let rv = r.yoy {
                        LineMark(x: .value("Kỳ", r.periodLabel), y: .value("YoY", scaleYoY(rv)))
                            .foregroundStyle(yoyLineColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Kỳ", r.periodLabel), y: .value("YoY", scaleYoY(rv)))
                            .foregroundStyle(yoyLineColor)
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
                    values: [-100.0, -50.0, 0.0, 50.0, 100.0].map { scaleYoY($0) }
                ) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(OpacityLevel.chartGrid))
                    AxisValueLabel {
                        if let mappedV = value.as(Double.self) {
                            Text("\(Int(round(unscaleYoY(mappedV))))%")
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

    private func makeMetrics(row: BarYoYRow) -> [ChartPopoverMetric] {
        var m: [ChartPopoverMetric] = []
        if let v = row.value {
            m.append(ChartPopoverMetric(id: "bar", label: barLabel, value: formatVndCompact(v), color: barColor))
        }
        m.append(ChartPopoverMetric(
            id: "yoy", label: yoyLabel,
            value: row.yoy.map { String(format: "%.2f%%", $0) } ?? "—",
            color: yoyLineColor
        ))
        return m
    }
}
