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
    /// Optional independent domain for `line2`. When provided, `line2` values are
    /// rescaled into `yDomain` for plotting, and a trailing Y-axis is rendered
    /// showing labels in the original `line2` scale.
    let secondaryYDomain: ClosedRange<Double>?

    init(
        items: [Item],
        labelKey: @escaping (Item) -> String,
        line1: DualLineSeries<Item>,
        line2: DualLineSeries<Item>,
        popoverSubtitle: String,
        height: CGFloat,
        fullScreen: Bool,
        yDomain: ClosedRange<Double>?,
        yAxisFormat: DualLineYAxisFormat,
        secondaryYDomain: ClosedRange<Double>? = nil
    ) {
        self.items = items
        self.labelKey = labelKey
        self.line1 = line1
        self.line2 = line2
        self.popoverSubtitle = popoverSubtitle
        self.height = height
        self.fullScreen = fullScreen
        self.yDomain = yDomain
        self.yAxisFormat = yAxisFormat
        self.secondaryYDomain = secondaryYDomain
    }

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

    /// Rescale a line2 raw value into line1's domain (linear map).
    /// Returns nil if dual-axis is disabled or domains are degenerate.
    private func mapLine2ToPrimary(_ v: Double) -> Double? {
        guard let primary = yDomain, let secondary = secondaryYDomain else { return nil }
        let p0 = primary.lowerBound, p1 = primary.upperBound
        let s0 = secondary.lowerBound, s1 = secondary.upperBound
        guard s1 > s0, p1 > p0 else { return nil }
        return (v - s0) / (s1 - s0) * (p1 - p0) + p0
    }

    /// Inverse map: turn a primary-domain value back into the secondary scale (for axis labels).
    private func mapPrimaryToLine2(_ v: Double) -> Double? {
        guard let primary = yDomain, let secondary = secondaryYDomain else { return nil }
        let p0 = primary.lowerBound, p1 = primary.upperBound
        let s0 = secondary.lowerBound, s1 = secondary.upperBound
        guard p1 > p0 else { return nil }
        return (v - p0) / (p1 - p0) * (s1 - s0) + s0
    }

    var body: some View {
        InteractiveChartScaffold(
            labels: labels,
            height: height,
            fullScreen: fullScreen,
            legendReserved: legendReserved,
            popoverBuilder: { _, idx in
                guard items.indices.contains(idx) else { return nil }
                let item = items[idx]
                return [
                    line1.value(item).map { v in
                        ChartPopoverMetric(id: line1.name, label: line1.name, value: String(format: "%.2f%%", v), color: line1.color)
                    },
                    line2.value(item).map { v in
                        ChartPopoverMetric(id: line2.name, label: line2.name, value: String(format: "%.2f%%", v), color: line2.color)
                    }
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
                    if let v2Raw = line2.value(item) {
                        let v2Plot = mapLine2ToPrimary(v2Raw) ?? v2Raw
                        LineMark(x: .value("Kỳ", label), y: .value(line2.name, v2Plot))
                            .foregroundStyle(by: .value("Chỉ số", line2.name))
                        PointMark(x: .value("Kỳ", label), y: .value(line2.name, v2Plot))
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
                if secondaryYDomain != nil {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine().foregroundStyle(Color.clear)
                        AxisValueLabel {
                            if let plotted = value.as(Double.self),
                               let original = mapPrimaryToLine2(plotted) {
                                if yAxisFormat == .percent {
                                    Text(String(format: "%.0f%%", original))
                                } else {
                                    Text(String(format: "%.1f", original))
                                }
                            }
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
