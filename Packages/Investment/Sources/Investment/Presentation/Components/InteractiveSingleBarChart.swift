import Charts
import FinFlowCore
import SwiftUI

struct InteractiveSingleBarChart: View {
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
        .onDisappear {
            hidePopoverTask?.cancel()
            hidePopoverTask = nil
        }
    }
}
