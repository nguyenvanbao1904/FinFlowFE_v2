import Charts
import FinFlowCore
import SwiftUI

/// Yearly dividend bars (cash + stock); scroll/X/Y behavior shared with `DividendHorizontalChartLayout` + Y helpers below.
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

    private struct YearlyDividendSummary: Identifiable {
        let year: Int
        let cashValuePerShare: Double
        let stockPercent: Double

        var id: Int { year }
    }

    private enum DividendBarSeriesAttributes {
        case cash
        case stock

        var plotYLabel: String {
            switch self {
            case .cash: return "Cổ tức tiền"
            case .stock: return "Cổ tức cổ phiếu (%)"
            }
        }

        var yKeyPath: KeyPath<YearlyDividendSummary, Double> {
            switch self {
            case .cash: return \.cashValuePerShare
            case .stock: return \.stockPercent
            }
        }

        var barColor: Color {
            switch self {
            case .cash: return AppColors.chartProfit
            case .stock: return AppColors.primary
            }
        }

        var selectionSubtitle: String {
            switch self {
            case .cash: return "Cổ tức tiền"
            case .stock: return "Cổ tức cổ phiếu"
            }
        }

        var metricTitle: String {
            switch self {
            case .cash: return "Tiền mặt"
            case .stock: return "Cổ phiếu thưởng"
            }
        }

        func yDomain(_ maxValue: Double) -> ClosedRange<Double> {
            switch self {
            case .cash: return dividendCashYDomain(maxValue: maxValue)
            case .stock: return dividendStockPercentYDomain(maxValue: maxValue)
            }
        }

        func formatAxisValue(_ v: Double) -> String {
            switch self {
            case .cash: return String(format: "%.0f", v)
            case .stock: return String(format: "%.0f%%", v)
            }
        }

        func formatMetric(_ row: YearlyDividendSummary) -> String {
            switch self {
            case .cash: return String(format: "%.0f đ/CP", row.cashValuePerShare)
            case .stock: return String(format: "%.1f%%", row.stockPercent)
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
            return YearlyDividendSummary(
                year: y,
                cashValuePerShare: v.cashValuePerShare,
                stockPercent: v.stockPercent
            )
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
            Text("Lịch sử cổ tức")
                .font(AppTypography.headline)

            if dividends.isEmpty || yearly.isEmpty {
                Text("Chưa có dữ liệu cổ tức")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            } else {
                cashDividendChart
                stockPercentChart
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    private var cashDividendChart: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text("Cổ tức tiền (đ/CP) theo năm")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                fullScreenButton { showCashFullscreen = true }
            }
            yearlyDividendBarChart(
                fullScreen: false,
                scrollYear: $cashScrollYear,
                selectedYear: $selectedCashYear,
                attributes: .cash
            )
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            legendRow(label: "Cổ tức tiền", color: AppColors.chartProfit)
        }
        .fullScreenCover(isPresented: $showCashFullscreen) {
            ChartFullscreenContainer(title: "Cổ tức tiền (đ/CP) theo năm") {
                GeometryReader { proxy in
                    let chartHeight = ChartFullscreenSupport.preferredChartHeight(for: proxy.size)
                    yearlyDividendBarChart(
                        fullScreen: true,
                        scrollYear: $cashScrollYear,
                        selectedYear: $selectedCashYear,
                        attributes: .cash
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: chartHeight)
                    .padding(Spacing.md)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                }
            }
        }
        .onChange(of: showCashFullscreen) { _, isPresented in
            if isPresented { onRequestFullHistory?() }
            if !isPresented { selectedCashYear = nil }
        }
    }

    private var stockPercentChart: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text("Cổ tức cổ phiếu (%) theo năm")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                fullScreenButton { showStockFullscreen = true }
            }
            yearlyDividendBarChart(
                fullScreen: false,
                scrollYear: $stockScrollYear,
                selectedYear: $selectedStockYear,
                attributes: .stock
            )
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            legendRow(label: "Cổ tức cổ phiếu (%)", color: AppColors.primary)
        }
        .fullScreenCover(isPresented: $showStockFullscreen) {
            ChartFullscreenContainer(title: "Cổ tức cổ phiếu (%) theo năm") {
                GeometryReader { proxy in
                    let chartHeight = ChartFullscreenSupport.preferredChartHeight(for: proxy.size)
                    yearlyDividendBarChart(
                        fullScreen: true,
                        scrollYear: $stockScrollYear,
                        selectedYear: $selectedStockYear,
                        attributes: .stock
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: chartHeight)
                    .padding(Spacing.md)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                }
            }
        }
        .onChange(of: showStockFullscreen) { _, isPresented in
            if isPresented { onRequestFullHistory?() }
            if !isPresented { selectedStockYear = nil }
        }
    }

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
            if let label = selectedYear.wrappedValue,
               let summary = summary(for: label)
            {
                selectionCard(
                    title: label,
                    subtitle: attributes.selectionSubtitle,
                    metrics: [
                        (label: attributes.metricTitle, value: attributes.formatMetric(summary), color: attributes.barColor),
                    ]
                )
                .frame(maxWidth: 220)
                .padding(.top, Spacing.xs)
                .padding(.trailing, Spacing.xs)
            }
        }
        .chartYScale(domain: attributes.yDomain(maxY))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(attributes.formatAxisValue(v))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel {
                    if let label = value.as(String.self),
                       shouldShowChartLabel(label, labels: labels, fullScreen: fullScreen) {
                        Text(label)
                    }
                }
            }
        }
        .modifier(
            DividendHorizontalChartLayout(
                labels: labels,
                needsScroll: needsDividendHorizontalScroll(fullScreen: fullScreen),
                fullScreen: fullScreen,
                inlineVisibleLength: inlineVisibleLength,
                fullVisibleLength: fullVisibleLength,
                scrollYear: scrollYear,
                initialInlineScrollLabel: initialInlineScrollLabel,
                initialFullScrollLabel: initialFullScrollLabel
            )
        )
        .onChange(of: years) { _, _ in
            syncScrollYearForDividendChart(fullScreen: fullScreen, scrollYear: scrollYear)
        }
    }

    private func syncScrollYearForDividendChart(fullScreen: Bool, scrollYear: Binding<String>) {
        guard needsDividendHorizontalScroll(fullScreen: fullScreen), !labels.isEmpty else { return }
        scrollYear.wrappedValue = fullScreen ? initialFullScrollLabel : initialInlineScrollLabel
    }

    private func fullScreenButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.primary)
                .frame(width: 28, height: 28)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private func legendRow(label: String, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(AppTypography.caption2)
                .foregroundStyle(.secondary)
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
            Text(title)
                .font(AppTypography.caption)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(AppTypography.caption2)
                .foregroundStyle(.secondary)
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                HStack(spacing: Spacing.xs) {
                    Circle().fill(metric.color).frame(width: 6, height: 6)
                    Text(metric.label)
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(metric.value)
                        .font(AppTypography.caption2)
                        .fontWeight(.semibold)
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
        let raw = ratio
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        guard !raw.isEmpty else { return 0 }

        if raw.contains(":") {
            let parts = raw.split(separator: ":")
            guard parts.count == 2,
                  let left = Double(parts[0]),
                  let right = Double(parts[1]),
                  left > 0
            else { return 0 }
            return (right / left) * 100
        }

        let normalized = raw.replacingOccurrences(of: "%", with: "")
        guard let value = Double(normalized) else { return 0 }
        if raw.contains("%") { return value }
        return value <= 1 ? value * 100 : value
    }
}

// MARK: - Y domain

private func dividendCashYDomain(maxValue: Double) -> ClosedRange<Double> {
    let headroom = 0.12
    guard maxValue > 0 else { return 0 ... 1 }
    let padded = maxValue * (1.0 + headroom)
    let t = pow(10.0, floor(log10(max(padded, 1e-9))))
    let step = [0.25, 0.5, 1, 2, 5, 10].map { $0 * t }.first { $0 >= padded / 5 } ?? (10 * t)
    let upper = max(ceil(padded / step) * step, maxValue * 1.001)
    return 0 ... upper
}

private func dividendStockPercentYDomain(maxValue: Double) -> ClosedRange<Double> {
    let headroom = 0.12
    guard maxValue > 0 else { return 0 ... 1 }
    let padded = maxValue * (1.0 + headroom)
    let upper = max(ceil(padded / 10.0) * 10.0, maxValue + 1)
    return 0 ... upper
}

// MARK: - Horizontal layout

private struct DividendHorizontalChartLayout: ViewModifier {
    let labels: [String]
    let needsScroll: Bool
    let fullScreen: Bool
    let inlineVisibleLength: Int
    let fullVisibleLength: Int
    @Binding var scrollYear: String
    let initialInlineScrollLabel: String
    let initialFullScrollLabel: String

    func body(content: Content) -> some View {
        Group {
            if needsScroll {
                if fullScreen {
                    content
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: fullVisibleLength)
                        .chartScrollPosition(x: .constant(initialFullScrollLabel))
                } else {
                    content
                        .chartScrollableAxes(.horizontal)
                        .chartXVisibleDomain(length: inlineVisibleLength)
                        .chartScrollPosition(x: inlineScrollPositionBinding)
                }
            } else {
                content
                    .chartXScale(domain: labels)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var inlineScrollPositionBinding: Binding<String> {
        Binding(
            get: { scrollYear.isEmpty ? initialInlineScrollLabel : scrollYear },
            set: { scrollYear = $0 }
        )
    }
}

private func shouldShowChartLabel(_ label: String, labels: [String], fullScreen: Bool) -> Bool {
    guard let idx = labels.firstIndex(of: label) else { return true }
    let stride = fullScreen ? max(1, labels.count / 12) : max(1, labels.count / 4)
    return idx == labels.count - 1 || idx % stride == 0
}
