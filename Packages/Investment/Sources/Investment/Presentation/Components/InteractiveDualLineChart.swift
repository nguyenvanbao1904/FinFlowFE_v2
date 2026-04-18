import Charts
import FinFlowCore
import SwiftUI

/// Generic dual-line chart used for ROE/ROA, Gross/Net Margins, etc.
/// Replaces InteractiveRoeRoaChart and InteractiveNonBankMarginsChart.
struct InteractiveDualLineChart<Item: Identifiable>: View {
    let items: [Item]
    let labelKey: (Item) -> String
    let line1: DualLineSeries<Item>
    let line2: DualLineSeries<Item>
    let popoverSubtitle: String
    let height: CGFloat
    let fullScreen: Bool
    let yDomain: ClosedRange<Double>?
    let yAxisFormat: DualLineYAxisFormat

    struct DualLineSeries<I> {
        let name: String
        let color: Color
        let value: (I) -> Double?
    }

    enum DualLineYAxisFormat {
        case percent   // "%.0f%%"
        case auto      // default AxisValueLabel
    }

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private var labels: [String] { items.map(labelKey) }
    private var visibleLength: Int { fullScreen ? min(8, max(1, items.count)) : min(4, max(1, items.count)) }
    private let legendReserved: CGFloat = 52
    private var chartHeight: CGFloat {
        fullScreen ? max(110, height - legendReserved - 20) : max(140, height - legendReserved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                ForEach(items) { item in
                    let label = labelKey(item)
                    if let v1 = line1.value(item) {
                        LineMark(x: .value("Kỳ", label), y: .value(line1.name, v1))
                            .foregroundStyle(by: .value("Chỉ số", line1.name))
                        PointMark(x: .value("Kỳ", label), y: .value(line1.name, v1))
                            .foregroundStyle(by: .value("Chỉ số", line1.name))
                    }
                    if let v2 = line2.value(item) {
                        LineMark(x: .value("Kỳ", label), y: .value(line2.name, v2))
                            .foregroundStyle(by: .value("Chỉ số", line2.name))
                        PointMark(x: .value("Kỳ", label), y: .value(line2.name, v2))
                            .foregroundStyle(by: .value("Chỉ số", line2.name))
                    }
                }
            }
            .chartForegroundStyleScale([line1.name: line1.color, line2.name: line2.color])
            .chartLegend(.hidden)
            .modifier(YDomainModifier(domain: yDomain))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    if yAxisFormat == .percent {
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f%%", v))
                            }
                        }
                    } else {
                        AxisValueLabel()
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
            .onChange(of: selectedLabel) { _, newValue in displayedLabel = newValue }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            HStack(spacing: Spacing.md) {
                chartLegendItem(line1.name, color: line1.color)
                chartLegendItem(line2.name, color: line2.color)
            }
            .frame(height: legendReserved, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let idx = labels.firstIndex(of: label), items.indices.contains(idx) {
                let item = items[idx]
                let metrics = [
                    line1.value(item).map { v in
                        ChartPopoverMetric(id: line1.name, label: line1.name, value: String(format: "%.2f%%", v), color: line1.color)
                    },
                    line2.value(item).map { v in
                        ChartPopoverMetric(id: line2.name, label: line2.name, value: String(format: "%.2f%%", v), color: line2.color)
                    },
                ].compactMap { $0 }
                nativeSelectionDetails(title: label, subtitle: popoverSubtitle, metrics: metrics)
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

/// ViewModifier to conditionally apply chartYScale
private struct YDomainModifier: ViewModifier {
    let domain: ClosedRange<Double>?

    func body(content: Content) -> some View {
        if let domain {
            content.chartYScale(domain: domain)
        } else {
            content
        }
    }
}
