import Charts
import FinFlowCore
import SwiftUI

struct InteractiveStackedBarChart<Item>: View {
    let items: [Item]
    let series: [(name: String, color: Color, value: (Item) -> Double?)]
    let yearKey: KeyPath<Item, Int>
    let quarterKey: KeyPath<Item, Int>?
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool
    let groupedLayout: Bool
    /// Thêm dòng vào popover fullscreen (vd: tổng tài sản).
    let extraPopoverMetrics: ((Item) -> [ChartPopoverMetric])?

    init(
        items: [Item],
        series: [(name: String, color: Color, value: (Item) -> Double?)],
        yearKey: KeyPath<Item, Int>,
        quarterKey: KeyPath<Item, Int>? = nil,
        showQuarterly: Bool = false,
        height: CGFloat,
        fullScreen: Bool,
        groupedLayout: Bool = false,
        extraPopoverMetrics: ((Item) -> [ChartPopoverMetric])? = nil
    ) {
        self.items = items
        self.series = series
        self.yearKey = yearKey
        self.quarterKey = quarterKey
        self.showQuarterly = showQuarterly
        self.height = height
        self.fullScreen = fullScreen
        self.groupedLayout = groupedLayout
        self.extraPopoverMetrics = extraPopoverMetrics
    }

    private var labels: [String] {
        items.map { item in
            let y = item[keyPath: yearKey]
            if showQuarterly, let qKey = quarterKey {
                let q = item[keyPath: qKey]
                return "Q\(q) \(y % 100)"
            }
            return "\(y)"
        }
    }

    private var legendReserved: CGFloat {
        if series.count <= 3 { return 26 }
        if series.count <= 6 { return 52 }
        return 78
    }

    private var barDomain: ClosedRange<Double> {
        var bounds: [Double] = [0]
        if groupedLayout {
            // Side-by-side bars: domain only needs to cover individual values.
            for item in items {
                for s in series {
                    if let v = s.value(item) { bounds.append(v) }
                }
            }
        } else {
            // Stack positive and negative contributions separately so that columns
            // with negative values (e.g. negative cash flow) get accurate domain.
            for item in items {
                var positiveSum: Double = 0
                var negativeSum: Double = 0
                for s in series {
                    guard let v = s.value(item) else { continue }
                    if v >= 0 { positiveSum += v } else { negativeSum += v }
                }
                bounds.append(positiveSum)
                bounds.append(negativeSum)
            }
        }
        return unifiedBarDomain(values: bounds)
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
                let baseMetrics = series.compactMap { s -> ChartPopoverMetric? in
                    guard let v = s.value(item) else { return nil }
                    return ChartPopoverMetric(id: s.name, label: s.name, value: formatVndCompact(v), color: s.color)
                }
                let extra = extraPopoverMetrics?(item) ?? []
                return extra + baseMetrics
            },
            popoverSubtitle: "Chi tiết thành phần",
            legend: {
                let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: min(series.count, 3))
                LazyVGrid(columns: columns, spacing: Spacing.xs) {
                    ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                        chartLegendItem(s.name, color: s.color)
                    }
                }
            }
        ) { scrollLabel, selectedLabel, chartHeight in
            stackedChart
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(Self.formatAxis(v)) }
                        }
                    }
                }
                .chartYScale(domain: barDomain)
                .interactiveChartModifiers(
                    scrollLabel: scrollLabel,
                    selectedLabel: selectedLabel,
                    visibleLength: fullScreen ? min(8, max(1, items.count)) : min(4, max(1, items.count)),
                    fullScreen: fullScreen,
                    chartHeight: chartHeight
                )
        }
    }

    private var stackedChart: some View {
        let indexedItems = Array(items.enumerated())
        let indexedSeries = Array(series.enumerated())
        return Chart {
            ForEach(indexedItems, id: \.offset) { idx, item in
                let label = labels[idx]
                ForEach(indexedSeries, id: \.offset) { _, s in
                    if let v = s.value(item) {
                        if groupedLayout {
                            BarMark(x: .value("Kỳ", label), y: .value(s.name, v))
                                .foregroundStyle(s.color)
                                .position(by: .value("Series", s.name))
                        } else {
                            BarMark(x: .value("Kỳ", label), y: .value(s.name, v))
                                .foregroundStyle(s.color)
                        }
                    }
                }
            }
        }
    }

    private static func formatAxis(_ value: Double) -> String {
        formatVndCompact(value)
    }
}
