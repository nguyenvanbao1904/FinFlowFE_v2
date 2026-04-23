import Charts
import FinFlowCore
import SwiftUI

/// Yearly dividend bars (cash + stock).
public struct DividendHistoryTable: View {
    let dividends: [DividendDataPoint]
    let onRequestFullHistory: (() -> Void)?
    @State private var showCashFullscreen = false
    @State private var showStockFullscreen = false
    @State private var cashScrollYear = ""
    @State private var stockScrollYear = ""
    @State private var selectedCashYear: String?
    @State private var selectedStockYear: String?

    public init(dividends: [DividendDataPoint], onRequestFullHistory: (() -> Void)? = nil) {
        self.dividends = dividends
        self.onRequestFullHistory = onRequestFullHistory
    }

    struct YearlyDividendSummary: Identifiable {
        let year: Int
        let cashValuePerShare: Double
        let stockPercent: Double
        var id: Int { year }
    }

    enum DividendBarSeriesAttributes {
        case cash, stock

        var plotYLabel: String {
            switch self { case .cash: "Cổ tức tiền"; case .stock: "Cổ tức cổ phiếu (%)" }
        }

        var yKeyPath: KeyPath<YearlyDividendSummary, Double> {
            switch self { case .cash: \.cashValuePerShare; case .stock: \.stockPercent }
        }

        var barColor: Color {
            switch self { case .cash: AppColors.chartProfit; case .stock: AppColors.primary }
        }

        var selectionSubtitle: String {
            switch self { case .cash: "Cổ tức tiền"; case .stock: "Cổ tức cổ phiếu" }
        }

        var metricTitle: String {
            switch self { case .cash: "Tiền mặt"; case .stock: "Cổ phiếu thưởng" }
        }

        func yDomain(_ maxValue: Double) -> ClosedRange<Double> {
            switch self {
            case .cash: dividendCashYDomain(maxValue: maxValue)
            case .stock: dividendStockPercentYDomain(maxValue: maxValue)
            }
        }

        func formatAxisValue(_ v: Double) -> String {
            switch self { case .cash: String(format: "%.0f", v); case .stock: String(format: "%.0f%%", v) }
        }

        func formatMetric(_ row: YearlyDividendSummary) -> String {
            switch self {
            case .cash: String(format: "%.0f đ/CP", row.cashValuePerShare)
            case .stock: String(format: "%.1f%%", row.stockPercent)
            }
        }
    }

    private var yearly: [YearlyDividendSummary] {
        var byYear: [Int: (cashValuePerShare: Double, stockPercent: Double)] = [:]
        for d in dividends {
            guard let year = extractYear(d) else { continue }
            var current = byYear[year] ?? (0, 0)
            if d.eventType == "CASH" {
                current.cashValuePerShare += max(0, d.value)
            } else {
                current.stockPercent += parseStockPercent(from: d.ratio)
            }
            byYear[year] = current
        }
        return byYear.keys.sorted().map { y in
            let v = byYear[y] ?? (0, 0)
            return YearlyDividendSummary(year: y, cashValuePerShare: v.cashValuePerShare, stockPercent: v.stockPercent)
        }
    }

    private var labels: [String] { yearly.map { String($0.year) } }
    private var years: [Int] { yearly.map(\.year) }
    private var inlineVisibleLength: Int { min(6, max(1, yearly.count)) }
    private var fullVisibleLength: Int { min(10, max(1, yearly.count)) }
    private var initialInlineScrollLabel: String {
        labels.isEmpty ? "" : labels[max(labels.count - inlineVisibleLength, 0)]
    }
    private var initialFullScrollLabel: String {
        labels.isEmpty ? "" : labels[max(labels.count - fullVisibleLength, 0)]
    }

    private func needsDividendHorizontalScroll(fullScreen: Bool) -> Bool {
        let cap = fullScreen ? fullVisibleLength : inlineVisibleLength
        return yearly.count > cap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Lịch sử cổ tức").font(AppTypography.headline)

            if dividends.isEmpty || yearly.isEmpty {
                Text("Chưa có dữ liệu cổ tức")
                    .font(AppTypography.caption).foregroundStyle(.secondary)
            } else {
                dividendChartSection(
                    title: "Cổ tức tiền (đ/CP) theo năm",
                    showFullscreen: $showCashFullscreen,
                    scrollYear: $cashScrollYear,
                    selectedYear: $selectedCashYear,
                    attributes: .cash
                )
                dividendChartSection(
                    title: "Cổ tức cổ phiếu (%) theo năm",
                    showFullscreen: $showStockFullscreen,
                    scrollYear: $stockScrollYear,
                    selectedYear: $selectedStockYear,
                    attributes: .stock
                )
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    // MARK: - Chart Section (shared for cash & stock)

    private func dividendChartSection(
        title: String,
        showFullscreen: Binding<Bool>,
        scrollYear: Binding<String>,
        selectedYear: Binding<String?>,
        attributes: DividendBarSeriesAttributes
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text(title).font(AppTypography.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                fullScreenButton { showFullscreen.wrappedValue = true }
            }
            yearlyDividendBarChart(fullScreen: false, scrollYear: scrollYear, selectedYear: selectedYear, attributes: attributes)
                .frame(maxWidth: .infinity).frame(height: UILayout.chartHeightCompact)
            legendRow(label: attributes.selectionSubtitle, color: attributes.barColor)
        }
        .fullScreenCover(isPresented: showFullscreen) {
            ChartFullscreenContainer(title: title) {
                GeometryReader { proxy in
                    let chartHeight = ChartFullscreenSupport.preferredChartHeight(for: proxy.size)
                    yearlyDividendBarChart(fullScreen: true, scrollYear: scrollYear, selectedYear: selectedYear, attributes: attributes)
                        .frame(maxWidth: .infinity).frame(height: chartHeight)
                        .padding(Spacing.md)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                }
            }
        }
        .onChange(of: showFullscreen.wrappedValue) { _, isPresented in
            if isPresented { onRequestFullHistory?() }
            if !isPresented { selectedYear.wrappedValue = nil }
        }
    }

    // MARK: - Bar Chart

    private func yearlyDividendBarChart(
        fullScreen: Bool,
        scrollYear: Binding<String>,
        selectedYear: Binding<String?>,
        attributes: DividendBarSeriesAttributes
    ) -> some View {
        let maxY = yearly.map { $0[keyPath: attributes.yKeyPath] }.max() ?? 0
        return ZStack(alignment: .topTrailing) {
            Chart(yearly) { item in
                BarMark(
                    x: .value("Năm", String(item.year)),
                    y: .value(attributes.plotYLabel, item[keyPath: attributes.yKeyPath])
                )
                .foregroundStyle(attributes.barColor)
            }
            .chartXSelection(value: selectedYear)
            if let label = selectedYear.wrappedValue, let summary = summary(for: label) {
                selectionCard(title: label, subtitle: attributes.selectionSubtitle, metrics: [
                    (label: attributes.metricTitle, value: attributes.formatMetric(summary), color: attributes.barColor),
                ])
                .frame(maxWidth: 220)
                .padding(.top, Spacing.xs).padding(.trailing, Spacing.xs)
            }
        }
        .chartYScale(domain: attributes.yDomain(maxY))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(attributes.formatAxisValue(v)) }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel {
                    if let label = value.as(String.self),
                       shouldShowDividendChartLabel(label, labels: labels, fullScreen: fullScreen) {
                        Text(label)
                    }
                }
            }
        }
        .modifier(DividendHorizontalChartLayout(
            labels: labels,
            needsScroll: needsDividendHorizontalScroll(fullScreen: fullScreen),
            fullScreen: fullScreen,
            inlineVisibleLength: inlineVisibleLength,
            fullVisibleLength: fullVisibleLength,
            scrollYear: scrollYear,
            initialInlineScrollLabel: initialInlineScrollLabel,
            initialFullScrollLabel: initialFullScrollLabel
        ))
        .onChange(of: years) { _, _ in
            syncScrollYear(fullScreen: fullScreen, scrollYear: scrollYear)
        }
    }

    // MARK: - Helpers

    private func syncScrollYear(fullScreen: Bool, scrollYear: Binding<String>) {
        guard needsDividendHorizontalScroll(fullScreen: fullScreen), !labels.isEmpty else { return }
        scrollYear.wrappedValue = fullScreen ? initialFullScrollLabel : initialInlineScrollLabel
    }

    private func fullScreenButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(AppTypography.caption).fontWeight(.semibold)
                .foregroundStyle(AppColors.primary)
                .frame(width: UILayout.toolbarButton, height: UILayout.toolbarButton)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(Circle())
        }
        .accessibilityLabel("Phóng to biểu đồ")
    }

    private func legendRow(label: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle().fill(color)
                .frame(width: UILayout.chartLegendDotMedium, height: UILayout.chartLegendDotMedium)
            Text(label).font(AppTypography.caption2).foregroundStyle(.secondary)
        }
    }

    private func summary(for label: String) -> YearlyDividendSummary? {
        guard let year = Int(label) else { return nil }
        return yearly.first(where: { $0.year == year })
    }

    private func selectionCard(
        title: String,
        subtitle: String,
        metrics: [(label: String, value: String, color: Color)]
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(AppTypography.caption).fontWeight(.semibold)
            Text(subtitle).font(AppTypography.caption2).foregroundStyle(.secondary)
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                HStack(spacing: Spacing.xs) {
                    Circle().fill(metric.color).frame(width: 6, height: 6)
                    Text(metric.label).font(AppTypography.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(metric.value).font(AppTypography.caption2).fontWeight(.semibold)
                }
            }
        }
        .padding(Spacing.sm)
        .background(AppColors.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private func extractYear(_ d: DividendDataPoint) -> Int? {
        if let dt = d.recordDate ?? d.exrightDate ?? d.issueDate {
            return Calendar.current.component(.year, from: dt)
        }
        return nil
    }

    private func parseStockPercent(from ratio: String) -> Double {
        let raw = ratio.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")
        guard !raw.isEmpty else { return 0 }

        if raw.contains(":") {
            let parts = raw.split(separator: ":")
            guard parts.count == 2, let left = Double(parts[0]), let right = Double(parts[1]), left > 0
            else { return 0 }
            return (right / left) * 100
        }

        let normalized = raw.replacingOccurrences(of: "%", with: "")
        guard let value = Double(normalized) else { return 0 }
        if raw.contains("%") { return value }
        return value <= 1 ? value * 100 : value
    }
}
