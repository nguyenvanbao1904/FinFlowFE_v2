import Charts
import FinFlowCore
import SwiftUI

struct InteractiveBankCapitalLeverageChart: View {
    let items: [BankFinancialDataPoint]
    let series: [(name: String, color: Color, value: (BankFinancialDataPoint) -> Double?)]
    let yearKey: KeyPath<BankFinancialDataPoint, Int>
    let quarterKey: KeyPath<BankFinancialDataPoint, Int>?
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    init(
        items: [BankFinancialDataPoint],
        series: [(name: String, color: Color, value: (BankFinancialDataPoint) -> Double?)],
        yearKey: KeyPath<BankFinancialDataPoint, Int>,
        quarterKey: KeyPath<BankFinancialDataPoint, Int>? = nil,
        showQuarterly: Bool = false,
        height: CGFloat,
        fullScreen: Bool
    ) {
        self.items = items
        self.series = series
        self.yearKey = yearKey
        self.quarterKey = quarterKey
        self.showQuarterly = showQuarterly
        self.height = height
        self.fullScreen = fullScreen
    }

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private let leverageLineColor: Color = Color.primary
    private let leverageTicks: [Double] = [5, 8, 11, 14, 17, 20]
    private let leverageMin: Double = 5
    private let leverageMax: Double = 20

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
    private var visibleLength: Int { fullScreen ? min(8, max(1, items.count)) : min(4, max(1, items.count)) }

    private var legendReserved: CGFloat {
        let count = series.count + 1
        if count <= 3 { return 26 }
        if count <= 6 { return 52 }
        return 78
    }
    private var chartHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    private var barDomain: ClosedRange<Double> {
        let totals = items.map { item in
            series.reduce(0) { acc, s in
                acc + (s.value(item) ?? 0)
            }
        }
        return unifiedBarDomain(values: totals)
    }

    private func clampLeverage(_ r: Double) -> Double {
        min(max(r, leverageMin), leverageMax)
    }

    private func leverageToY(_ r: Double) -> Double {
        let yMin = barDomain.lowerBound
        let yMax = barDomain.upperBound
        let span = max(yMax - yMin, 1e-9)
        let t = (clampLeverage(r) - leverageMin) / max(leverageMax - leverageMin, 1e-9)
        return yMin + t * span
    }

    private func yToLeverage(_ y: Double) -> Double {
        let yMin = barDomain.lowerBound
        let yMax = barDomain.upperBound
        let span = max(yMax - yMin, 1e-9)
        let t = (y - yMin) / span
        return leverageMin + t * (leverageMax - leverageMin)
    }

    private func leverageRatio(for item: BankFinancialDataPoint) -> Double? {
        guard let assets = item.totalAssets, let eq = item.equity, eq != 0 else { return nil }
        return assets / eq
    }

    private var leverageTickYs: [Double] { leverageTicks.map(leverageToY) }

    private var capitalLeverageChartMarks: some View {
        Chart {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                let label = labels[idx]
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    if let v = s.value(item) {
                        BarMark(x: .value("Kỳ", label), y: .value(s.name, v))
                            .foregroundStyle(s.color)
                    }
                }
            }
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                if let r = leverageRatio(for: item) {
                    let label = labels[idx]
                    LineMark(
                        x: .value("Kỳ", label),
                        y: .value("TS/VCSH", leverageToY(r))
                    )
                    .foregroundStyle(leverageLineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Kỳ", label),
                        y: .value("TS/VCSH", leverageToY(r))
                    )
                    .foregroundStyle(leverageLineColor)
                    .symbolSize(30)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            capitalLeverageChartMarks
                .chartYScale(domain: barDomain, range: .plotDimension(padding: 0.1))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) {
                        AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                        AxisValueLabel().font(AppTypography.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatVndCompact(v))
                                    .font(AppTypography.caption2)
                                    .offset(x: Spacing.xs)
                            }
                        }
                    }

                    AxisMarks(position: .leading, values: leverageTickYs) { value in
                        AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                        AxisValueLabel {
                            if let y = value.as(Double.self) {
                                let r = yToLeverage(y)
                                Text("\(Int(round(r)))x")
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
                .frame(height: chartHeight)

            let legendItems: [(String, Color)] = series.map { ($0.name, $0.color) } + [("TS/VCSH", leverageLineColor)]
            let columnsCount = min(legendItems.count, 3)
            let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: columnsCount)
            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                ForEach(Array(legendItems.enumerated()), id: \.offset) { _, it in
                    chartLegendItem(it.0, color: it.1)
                }
            }
            .frame(height: legendReserved, alignment: .top)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let metrics = selectionMetrics(for: label) {
                nativeSelectionDetails(
                    title: label,
                    subtitle: "Chi tiết thành phần",
                    metrics: metrics
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

    private func selectionMetrics(for label: String) -> [ChartPopoverMetric]? {
        guard let idx = labels.firstIndex(of: label), items.indices.contains(idx) else { return nil }
        let item = items[idx]

        let baseMetrics = series.compactMap { s -> ChartPopoverMetric? in
            guard let v = s.value(item) else { return nil }
            return ChartPopoverMetric(
                id: s.name,
                label: s.name,
                value: formatVndCompact(v),
                color: s.color
            )
        }

        let leverageMetrics: [ChartPopoverMetric] = leverageRatio(for: item).map { r in
            let clamped = clampLeverage(r)
            let text = "\(String(format: "%.2f", r))x"
            return ChartPopoverMetric(
                id: "leverage",
                label: "Đòn bẩy TS/VCSH",
                value: text + (abs(r - clamped) > 1e-9 ? " (clamp)" : ""),
                color: leverageLineColor
            )
        }.map { [$0] } ?? []

        let totalLiabMetrics: [ChartPopoverMetric] = item.totalLiabilities.map { v in
            [ChartPopoverMetric(id: "liab", label: "Tổng nợ phải trả", value: formatVndCompact(v), color: Color.red)]
        } ?? []

        return baseMetrics + totalLiabMetrics + leverageMetrics
    }
}
