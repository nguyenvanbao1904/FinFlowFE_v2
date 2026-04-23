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

    private var labels: [String] { items.map(labelKey) }
    private let legendReserved: CGFloat = 52

    var body: some View {
        InteractiveChartScaffold(
            labels: labels,
            height: height,
            fullScreen: fullScreen,
            legendReserved: legendReserved,
            popoverBuilder: { label, idx in
                guard items.indices.contains(idx) else { return nil }
                let item = items[idx]
                return [
                    line1.value(item).map { v in
                        ChartPopoverMetric(id: line1.name, label: line1.name, value: String(format: "%.2f%%", v), color: line1.color)
                    },
                    line2.value(item).map { v in
                        ChartPopoverMetric(id: line2.name, label: line2.name, value: String(format: "%.2f%%", v), color: line2.color)
                    },
                ].compactMap { $0 }
            },
            popoverSubtitle: popoverSubtitle,
            legend: {
                HStack(spacing: Spacing.md) {
                    chartLegendItem(line1.name, color: line1.color)
                    chartLegendItem(line2.name, color: line2.color)
                }
            }
        ) { scrollLabel, selectedLabel, chartHeight in
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
