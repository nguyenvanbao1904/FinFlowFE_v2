import Charts
import FinFlowCore
import SwiftUI

// MARK: - Bank: Bức tranh NIM

struct InteractiveBankNimChart: View {
    let items: [BankFinancialDataPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    /// Thứ tự khớp backend: (year, quarter) tăng dần.
    private var sortedItems: [BankFinancialDataPoint] { items }

    private var labels: [String] {
        sortedItems.map { item in
            if showQuarterly && item.quarter != 0 {
                return "Q\(item.quarter) \(item.year % 100)"
            }
            return "\(item.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, items.count)) : min(4, max(1, items.count)) }
    private let legendReserved: CGFloat = 52
    private var chartPlotHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    private let bgBarColor = Color.primary.opacity(0.15)
    private let fgBarColor = Color.red
    private let lineLineColor = AppColors.chartGrowthStrong

    private func grossInterest(for item: BankFinancialDataPoint) -> Double {
        let net = item.netInterestIncome ?? 0
        let exp = abs(item.interestExpense ?? 0)
        return net + exp
    }

    private func nim(for item: BankFinancialDataPoint) -> Double? {
        guard let ta = item.totalAssets, ta > 0 else { return nil }
        let net = item.netInterestIncome ?? 0
        // Dữ liệu lợi nhuận đang là 1 Quý, cần Annualized (X4) để tính NIM TTM tương đương
        return ((net * 4.0) / ta) * 100
    }

    private var barDomain: ClosedRange<Double> {
        let vals = sortedItems.map { grossInterest(for: $0) }
        return unifiedBarDomain(values: vals)
    }

    private var lineDomain: ClosedRange<Double> {
        // Y-axis cho % NIM (xử lý giống chart YoY nhưng giới hạn để dễ đọc).
        // Yêu cầu: đỉnh 15%, đáy -15%.
        return -15 ... 15
    }

    private func clampLineForPlot(_ v: Double) -> Double {
        min(max(v, lineDomain.lowerBound), lineDomain.upperBound)
    }

    private func scaleLineToBarDomain(_ val: Double) -> Double {
        let clamped = clampLineForPlot(val)
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = bMax - bMin
        let lMin = lineDomain.lowerBound
        let lSpan = lineDomain.upperBound - lMin
        guard lSpan > 0 else { return bMin }
        return bMin + ((clamped - lMin) / lSpan) * bSpan
    }

    private func scaleBarDomainToLine(_ mappedY: Double) -> Double {
        let bMin = barDomain.lowerBound
        let bMax = barDomain.upperBound
        let bSpan = max(bMax - bMin, 1e-9)
        let lMin = lineDomain.lowerBound
        let lSpan = lineDomain.upperBound - lMin
        return lMin + ((mappedY - bMin) / bSpan) * lSpan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                ForEach(Array(sortedItems.enumerated()), id: \.offset) { idx, item in
                    let label = labels[idx]
                    let gross = grossInterest(for: item)
                    let exp = abs(item.interestExpense ?? 0)

                    BarMark(
                        x: .value("Kỳ", label),
                        y: .value("Tổng thu lãi", gross)
                    )
                    .foregroundStyle(bgBarColor)

                    BarMark(
                        x: .value("Kỳ", label),
                        y: .value("Chi phí lãi", exp)
                    )
                    .foregroundStyle(fgBarColor)

                    if let n = nim(for: item) {
                        let scaled = scaleLineToBarDomain(n)
                        LineMark(
                            x: .value("Kỳ", label),
                            y: .value("NIM", scaled)
                        )
                        .foregroundStyle(lineLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Kỳ", label),
                            y: .value("NIM", scaled)
                        )
                        .foregroundStyle(lineLineColor)
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
                    values: [-15.0, -7.5, 0.0, 7.5, 15.0].map { scaleLineToBarDomain($0) }
                ) { value in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine.opacity(0.35))
                    AxisValueLabel {
                        if let mappedV = value.as(Double.self) {
                            let pct = scaleBarDomainToLine(mappedV)
                            Text("\(Int(round(pct)))%")
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

            let cols = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3)
            LazyVGrid(columns: cols, spacing: Spacing.xs) {
                chartLegendItem("Tổng thu lãi", color: bgBarColor)
                chartLegendItem("Chi phí lãi", color: fgBarColor)
                chartLegendItem("NIM ước tính", color: lineLineColor)
            }
            .frame(minHeight: legendReserved, alignment: .top)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen,
                let label = displayedLabel,
                let idx = labels.firstIndex(of: label),
                sortedItems.indices.contains(idx)
            {
                let item = sortedItems[idx]

                let gross = grossInterest(for: item)
                let exp = abs(item.interestExpense ?? 0)
                let net = item.netInterestIncome ?? 0

                let nimMetric = nim(for: item).map { n in
                    ChartPopoverMetric(
                        id: "nim",
                        label: "NIM (Ước tính TTM)",
                        value: String(format: "%.2f%%", n),
                        color: lineLineColor
                    )
                }

                let mt: [ChartPopoverMetric] = [
                    ChartPopoverMetric(
                        id: "gross",
                        label: "Tổng thu lãi",
                        value: formatVndCompact(gross),
                        color: bgBarColor
                    ),
                    ChartPopoverMetric(
                        id: "exp",
                        label: "Chi phí lãi",
                        value: formatVndCompact(exp),
                        color: fgBarColor
                    ),
                    ChartPopoverMetric(
                        id: "net",
                        label: "Lãi thuần",
                        value: formatVndCompact(net),
                        color: AppColors.chartIncomeInterest
                    ),
                ] + (nimMetric.map { [$0] } ?? [])
                nativeSelectionDetails(title: label, subtitle: "Biên lãi thuần", metrics: mt)
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
