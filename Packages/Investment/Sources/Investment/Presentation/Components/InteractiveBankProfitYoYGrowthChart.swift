import Charts
import FinFlowCore
import SwiftUI

struct InteractiveBankProfitYoYGrowthChart: View {
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
        points.enumerated().map { _, p in
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
        .onDisappear {
            hidePopoverTask?.cancel()
            hidePopoverTask = nil
        }
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
