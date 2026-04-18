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
    }

    // MARK: - State

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    // MARK: - Computed

    private var labels: [String] { rows.map(\.periodLabel) }
    private var visibleLength: Int { fullScreen ? min(8, max(1, rows.count)) : min(4, max(1, rows.count)) }
    private let legendReserved: CGFloat = 52

    private var chartPlotHeight: CGFloat {
        fullScreen ? max(110, height - legendReserved - 20) : max(140, height - legendReserved)
    }

    private var barDomain: ClosedRange<Double> {
        unifiedBarDomain(values: rows.compactMap(\.value))
    }

    private let yoyDomain: ClosedRange<Double> = -100...100

    private var yoyRows: [YoYEntry] {
        var out: [YoYEntry] = []
        for i in rows.indices {
            var yoy: Double?
            if i > 0, let c = rows[i].value, let p = rows[i - 1].value, p != 0 {
                yoy = (c - p) / p * 100
            }
            out.append(YoYEntry(id: rows[i].id, periodLabel: rows[i].periodLabel, yoy: yoy))
        }
        return out
    }

    private struct YoYEntry: Identifiable {
        let id: String
        let periodLabel: String
        let yoy: Double?
    }

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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            chartContent
            legendRow
        }
        .overlay(alignment: .topTrailing) { popoverOverlay }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear {
            hidePopoverTask?.cancel()
            hidePopoverTask = nil
        }
    }

    private var chartContent: some View {
        Chart {
            ForEach(rows) { row in
                if let v = row.value {
                    BarMark(x: .value("Kỳ", row.periodLabel), y: .value("Giá trị", v))
                        .foregroundStyle(barColor)
                }
            }

            RuleMark(y: .value("0%", scaleYoY(0)))
                .foregroundStyle(Color.primary.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

            ForEach(yoyRows) { y in
                if let rv = y.yoy {
                    LineMark(x: .value("Kỳ", y.periodLabel), y: .value("YoY", scaleYoY(rv)))
                        .foregroundStyle(yoyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Kỳ", y.periodLabel), y: .value("YoY", scaleYoY(rv)))
                        .foregroundStyle(yoyLineColor)
                        .symbolSize(36)
                }
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) {
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
                values: [-100.0, -50.0, 0.0, 50.0, 100.0].map { scaleYoY($0) }
            ) { value in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                AxisValueLabel {
                    if let mappedV = value.as(Double.self) {
                        Text("\(Int(round(unscaleYoY(mappedV))))%")
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
        .onChange(of: selectedLabel) { _, newValue in displayedLabel = newValue }
        .padding(.top, fullScreen ? -Spacing.sm : 0)
        .frame(height: chartPlotHeight)
    }

    private var legendRow: some View {
        HStack(spacing: Spacing.md) {
            chartLegendItem(barLabel, color: barColor)
            chartLegendItem(yoyLabel, color: yoyLineColor)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: legendReserved, alignment: .center)
    }

    @ViewBuilder
    private var popoverOverlay: some View {
        if fullScreen,
           let label = displayedLabel,
           let idx = labels.firstIndex(of: label),
           rows.indices.contains(idx)
        {
            let row = rows[idx]
            let yoy = yoyRows.indices.contains(idx) ? yoyRows[idx].yoy : nil
            let metrics = makeMetrics(row: row, yoy: yoy)
            nativeSelectionDetails(title: label, subtitle: popoverSubtitle, metrics: metrics)
                .frame(maxWidth: 280)
                .padding(.top, Spacing.sm)
                .padding(.trailing, Spacing.sm)
        }
    }

    private func makeMetrics(row: BarYoYRow, yoy: Double?) -> [ChartPopoverMetric] {
        var m: [ChartPopoverMetric] = []
        if let v = row.value {
            m.append(ChartPopoverMetric(id: "bar", label: barLabel, value: formatVndCompact(v), color: barColor))
        }
        m.append(ChartPopoverMetric(
            id: "yoy", label: yoyLabel,
            value: yoy.map { String(format: "%.2f%%", $0) } ?? "—",
            color: yoyLineColor
        ))
        return m
    }
}
