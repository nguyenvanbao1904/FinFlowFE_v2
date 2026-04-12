import Charts
import FinFlowCore
import SwiftUI

enum NonBankMetricYoYKind {
    case revenue
    case profit
}

struct InteractiveNonBankMetricYoYChart: View {
    let kind: NonBankMetricYoYKind
    let items: [NonBankFinancialDataPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    private struct Row: Identifiable {
        let id: String
        let periodLabel: String
        let value: Double?
    }

    private struct YoYRow: Identifiable {
        let id: String
        let periodLabel: String
        let yoy: Double?
    }

    private var rows: [Row] {
        items.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }.map { item in
            let v: Double?
            switch kind {
            case .revenue: v = item.netRevenue
            case .profit: v = item.profitAfterTax
            }
            return Row(id: item.id.uuidString, periodLabel: item.periodLabel, value: v)
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
            out.append(YoYRow(id: cur.id, periodLabel: cur.periodLabel, yoy: yoy))
        }
        return out
    }

    private var barDomain: ClosedRange<Double> {
        let vals = rows.compactMap(\.value)
        return unifiedBarDomain(values: vals)
    }

    private var yoyDomain: ClosedRange<Double> {
        -100 ... 100
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
        switch kind {
        case .revenue: AppColors.chartRevenue
        case .profit: AppColors.chartProfit
        }
    }

    private var barLegendLabel: String {
        switch kind {
        case .revenue: "Doanh thu"
        case .profit: "LNST"
        }
    }

    /// Cam nổi bật trên nền tối; tách biệt rõ với cột cyan (DT) hoặc xanh (LNST).
    private var yoyLineColor: Color {
        AppColors.chartGrowthStable
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

    private var labels: [String] { rows.map(\.periodLabel) }
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
                ForEach(rows) { row in
                    if let v = row.value {
                        BarMark(
                            x: .value("Kỳ", row.periodLabel),
                            y: .value("Giá trị", v)
                        )
                        .foregroundStyle(barColor)
                    }
                }

                RuleMark(y: .value("0%", scaleYoYToBarDomain(0)))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))

                ForEach(yoyRows) { y in
                    if let rv = y.yoy {
                        LineMark(
                            x: .value("Kỳ", y.periodLabel),
                            y: .value("YoY", scaleYoYToBarDomain(rv))
                        )
                        .foregroundStyle(yoyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Kỳ", y.periodLabel),
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
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) {
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
        .onDisappear {
            hidePopoverTask?.cancel()
            hidePopoverTask = nil
        }
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
