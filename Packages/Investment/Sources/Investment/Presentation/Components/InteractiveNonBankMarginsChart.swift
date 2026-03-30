import Charts
import FinFlowCore
import SwiftUI

struct InteractiveNonBankMarginsChart: View {
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
        .onDisappear {
            hidePopoverTask?.cancel()
            hidePopoverTask = nil
        }
    }
}
