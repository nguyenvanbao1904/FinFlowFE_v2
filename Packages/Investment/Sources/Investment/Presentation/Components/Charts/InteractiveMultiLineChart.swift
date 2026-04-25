import Charts
import FinFlowCore
import SwiftUI

enum MultiLineYAxisFormat {
    case percent
    case auto
}

struct MultiLineSeries<Item> {
    let name: String
    let color: Color
    let value: (Item) -> Double?
}

struct InteractiveMultiLineChart<Item: Identifiable>: View {
    let items: [Item]
    let labelKey: (Item) -> String
    let lines: [MultiLineSeries<Item>]
    let popoverSubtitle: String
    let height: CGFloat
    let fullScreen: Bool
    let yDomain: ClosedRange<Double>?
    let yAxisFormat: MultiLineYAxisFormat
    let valueFormat: String

    init(
        items: [Item],
        labelKey: @escaping (Item) -> String,
        lines: [MultiLineSeries<Item>],
        popoverSubtitle: String,
        height: CGFloat,
        fullScreen: Bool,
        yDomain: ClosedRange<Double>? = nil,
        yAxisFormat: MultiLineYAxisFormat = .percent,
        valueFormat: String = "%.2f%%"
    ) {
        self.items = items
        self.labelKey = labelKey
        self.lines = lines
        self.popoverSubtitle = popoverSubtitle
        self.height = height
        self.fullScreen = fullScreen
        self.yDomain = yDomain
        self.yAxisFormat = yAxisFormat
        self.valueFormat = valueFormat
    }

    private var labels: [String] { items.map(labelKey) }
    private let legendReserved: CGFloat = 52

    var body: some View {
        InteractiveChartScaffold(
            labels: labels,
            height: height,
            fullScreen: fullScreen,
            legendReserved: legendReserved,
            popoverBuilder: { _, idx in
                guard items.indices.contains(idx) else { return nil }
                let item = items[idx]
                return lines.compactMap { line in
                    line.value(item).map { v in
                        let formatted: String
                        if yAxisFormat == .auto {
                            formatted = formatVndCompact(v)
                        } else {
                            formatted = String(format: valueFormat, v)
                        }
                        return ChartPopoverMetric(
                            id: line.name,
                            label: line.name,
                            value: formatted,
                            color: line.color
                        )
                    }
                }
            },
            popoverSubtitle: popoverSubtitle,
            legend: {
                HStack(spacing: Spacing.md) {
                    ForEach(lines.indices, id: \.self) { i in
                        chartLegendItem(lines[i].name, color: lines[i].color)
                    }
                }
            }
        ) { scrollLabel, selectedLabel, chartHeight in
            Chart {
                ForEach(lines.indices, id: \.self) { i in
                    ForEach(items) { item in
                        let label = labelKey(item)
                        if let v = lines[i].value(item) {
                            LineMark(
                                x: .value("Kỳ", label),
                                y: .value("Giá trị", v),
                                series: .value("Chỉ số", lines[i].name)
                            )
                            .foregroundStyle(lines[i].color)
                            PointMark(x: .value("Kỳ", label), y: .value("Giá trị", v))
                                .foregroundStyle(lines[i].color)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .modifier(YDomainModifier(domain: yDomain))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            switch yAxisFormat {
                            case .percent:
                                Text(String(format: "%.0f%%", v))
                            case .auto:
                                Text(formatVndCompact(v))
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
