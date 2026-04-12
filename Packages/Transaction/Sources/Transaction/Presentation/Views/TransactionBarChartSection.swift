//
//  TransactionBarChartSection.swift
//  Transaction
//
//  Interactive bar-chart section used by TransactionAnalyticsView.
//  Manages its own bar-selection state so the parent stays lean.
//

import Charts
import FinFlowCore
import SwiftUI

// MARK: - Layout constant (shared with TransactionAnalyticsView)
enum TransactionChartLayout {
    static let chartHeight: CGFloat = 220
}

// MARK: - TransactionBarChartSection

struct TransactionBarChartSection: View {

    let chartData: TransactionChartResponse?
    let currentRange: ChartRange
    let isChartLoading: Bool
    let hasLoadError: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void
    let onRetry: (() -> Void)?

    @State private var selectedPlotSlot: Int?
    @State private var selectedWeekday: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            navigationHeader
            chartContent
                .padding(.vertical, AppSpacing.sm)
        }
        .onChange(of: selectedPlotSlot) { _, newValue in
            if newValue != nil { ChartSelectionHaptics.selectionChanged() }
        }
        .onChange(of: selectedWeekday) { _, newValue in
            if newValue != nil { ChartSelectionHaptics.selectionChanged() }
        }
        .onChange(of: currentRange) { _, _ in
            selectedPlotSlot = nil
            selectedWeekday = nil
        }
    }

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        let canGoForward = chartData?.hasNext ?? false
        return HStack(spacing: AppSpacing.sm) {
            Button(action: onNavigateBack) {
                Image(systemName: "chevron.left")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(isChartLoading)
            .buttonStyle(.plain)
            Spacer()
            Text(chartData?.periodLabel ?? "Biến động Số Dư")
                .font(AppTypography.headline)
                .foregroundStyle(.primary)
            Spacer()
            Button(action: onNavigateForward) {
                Image(systemName: "chevron.right")
                    .font(AppTypography.body)
                    .foregroundStyle(
                        canGoForward ? AppColors.primary : .secondary.opacity(OpacityLevel.low)
                    )
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoForward || isChartLoading)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        if isChartLoading {
            TransactionAnalyticsChartStateView(icon: nil, title: nil, showProgress: true,
                                               hasLoadError: hasLoadError, onRetry: onRetry)
        } else if hasLoadError {
            TransactionAnalyticsChartStateView(icon: "wifi.exclamationmark",
                                               title: "Không thể tải thống kê",
                                               showProgress: false,
                                               hasLoadError: hasLoadError, onRetry: onRetry)
        } else if !hasPlottableValues {
            TransactionAnalyticsChartStateView(icon: "chart.bar.xaxis",
                                               title: "Chưa có dữ liệu thống kê",
                                               showProgress: false,
                                               hasLoadError: hasLoadError, onRetry: onRetry)
        } else if currentRange == .week {
            weekChartBarView
        } else {
            numericChartBarView
        }
    }

    private var hasPlottableValues: Bool {
        guard let data = chartData, !data.dataPoints.isEmpty else { return false }
        return data.dataPoints.contains { $0.income != 0 || $0.expense != 0 }
    }

    // MARK: - Week Chart

    private var weekChartBarView: some View {
        let rows = mappedWeekBarRows
        let labelSource = chartData?.dataPoints ?? []

        return ZStack(alignment: .top) {
            Chart {
                ForEach(rows) { row in
                    BarMark(x: .value("Thứ", row.weekday), y: .value("Số tiền", row.amount))
                        .foregroundStyle(by: .value("Loại", row.series))
                        .opacity(selectedWeekday == nil || selectedWeekday == row.weekday
                                 ? 1.0 : OpacityLevel.low)
                }
            }
            .chartForegroundStyleScale(["Thu nhập": AppColors.success, "Chi tiêu": AppColors.google])
            .chartLegend(position: .top, alignment: .leading)
            .chartXScale(domain: Self.weekdayCategories)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(CurrencyFormatter.formatAxisValue(abs(v))).font(AppTypography.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: Self.weekdayCategories) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label).font(AppTypography.caption2).lineLimit(1).minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedWeekday)
            .frame(height: TransactionChartLayout.chartHeight)

            if let idx = weekdayIndex(for: selectedWeekday), idx < labelSource.count {
                barDetailOverlay(for: labelSource[idx], selectedIndex: idx, totalCount: labelSource.count)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22), value: selectedWeekday)
    }

    // MARK: - Numeric Chart (month / quarter / year)

    private var numericChartBarView: some View {
        let rows = mappedBarRows
        let labelSource = chartData?.dataPoints ?? []
        let tickValues = xAxisTickSlots()
        let xDomain = chartXDomainInt()

        return ZStack(alignment: .top) {
            Chart {
                ForEach(rows) { row in
                    BarMark(x: .value("Kỳ", row.plotSlot), y: .value("Số tiền", row.amount))
                        .foregroundStyle(by: .value("Loại", row.series))
                        .opacity(selectedPlotSlot == nil || selectedPlotSlot == row.plotSlot
                                 ? 1.0 : OpacityLevel.low)
                }
            }
            .chartForegroundStyleScale(["Thu nhập": AppColors.success, "Chi tiêu": AppColors.google])
            .chartLegend(position: .top, alignment: .leading)
            .chartXScale(domain: xDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(CurrencyFormatter.formatAxisValue(abs(v))).font(AppTypography.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: tickValues) { value in
                    AxisValueLabel {
                        if let slot = value.as(Int.self) {
                            Text("\(slot)").font(AppTypography.caption2).lineLimit(1).minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedPlotSlot)
            .frame(height: TransactionChartLayout.chartHeight)

            if let idx = numericDataIndex(for: selectedPlotSlot), idx < labelSource.count {
                barDetailOverlay(for: labelSource[idx], selectedIndex: idx, totalCount: labelSource.count)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22), value: selectedPlotSlot)
    }

    // MARK: - Bar Detail Overlay

    private func barDetailOverlay(
        for dataPoint: TransactionChartResponse.ChartDataPoint,
        selectedIndex: Int,
        totalCount: Int
    ) -> some View {
        let ratio = Double(selectedIndex) / Double(max(totalCount - 1, 1))

        return HStack(spacing: .zero) {
            if ratio > 0.34 { Spacer(minLength: 0) }
            ChartSelectionPopover(
                title: dataPoint.label,
                subtitle: "Giữ và kéo để xem kỳ khác",
                metrics: [
                    ChartPopoverMetric(id: "income",   label: "Thu",       value: CurrencyFormatter.format(dataPoint.income),  color: AppColors.success),
                    ChartPopoverMetric(id: "expense",  label: "Chi",       value: CurrencyFormatter.format(dataPoint.expense), color: AppColors.google),
                    ChartPopoverMetric(id: "balance",  label: "Chênh lệch",value: CurrencyFormatter.format(dataPoint.income - dataPoint.expense),
                                       color: dataPoint.income >= dataPoint.expense ? AppColors.success : AppColors.google),
                ]
            )
            .frame(maxWidth: 290)
            if ratio < 0.66 { Spacer(minLength: 0) }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }

    // MARK: - Data Mapping

    private struct ChartBarRow: Identifiable {
        let id: String
        let plotSlot: Int
        let series: String
        let amount: Double
    }

    private struct WeekChartBarRow: Identifiable {
        let id: String
        let weekday: String
        let series: String
        let amount: Double
    }

    private static let weekdayCategories: [String] = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    private var mappedBarRows: [ChartBarRow] {
        guard let data = chartData else { return [] }
        return data.dataPoints.enumerated().flatMap { index, point in
            let slot = plotSlot(forIndex: index, label: point.label)
            return [
                ChartBarRow(id: "\(slot)-thu-\(index)",  plotSlot: slot, series: "Thu nhập", amount: point.income),
                ChartBarRow(id: "\(slot)-chi-\(index)",  plotSlot: slot, series: "Chi tiêu", amount: -point.expense),
            ]
        }
    }

    private var mappedWeekBarRows: [WeekChartBarRow] {
        guard let data = chartData else { return [] }
        return data.dataPoints.enumerated().flatMap { index, point in
            let day = Self.weekdayCategories[min(index, Self.weekdayCategories.count - 1)]
            return [
                WeekChartBarRow(id: "\(day)-thu-\(index)", weekday: day, series: "Thu nhập", amount: point.income),
                WeekChartBarRow(id: "\(day)-chi-\(index)", weekday: day, series: "Chi tiêu", amount: -point.expense),
            ]
        }
    }

    // MARK: - Axis Helpers

    private func plotSlot(forIndex index: Int, label: String) -> Int {
        switch currentRange {
        case .month, .week:
            return index + 1
        case .quarter, .year:
            if let date = Self.axisDateFormatter.date(from: label) {
                return Calendar(identifier: .gregorian).component(.month, from: date)
            }
            return index + 1
        }
    }

    private func chartXDomainInt() -> ClosedRange<Int> {
        guard let points = chartData?.dataPoints, !points.isEmpty else { return 1...1 }
        switch currentRange {
        case .month:
            return 1...points.count
        case .week:
            return 1...1
        case .quarter, .year:
            let slots = points.enumerated().map { plotSlot(forIndex: $0.offset, label: $0.element.label) }
            return (slots.min() ?? 1)...(slots.max() ?? 1)
        }
    }

    private func xAxisTickSlots() -> [Int] {
        guard let points = chartData?.dataPoints, !points.isEmpty else { return [] }
        let n = points.count
        let step = xAxisStride(for: currentRange, count: n)
        switch currentRange {
        case .month:
            return Array(stride(from: 1, through: n, by: step))
        case .week:
            return Array(1...7)
        case .quarter, .year:
            let slots = (0..<n).map { plotSlot(forIndex: $0, label: points[$0].label) }
            return (0..<n).filter { $0 % step == 0 }.map { slots[$0] }
        }
    }

    private func xAxisStride(for range: ChartRange, count: Int) -> Int {
        guard range == .month else { return 1 }
        if count <= 15 { return 2 }
        if count <= 22 { return 3 }
        return 4
    }

    private func weekdayIndex(for key: String?) -> Int? {
        guard let key, let wi = Self.weekdayCategories.firstIndex(of: key),
              let points = chartData?.dataPoints, wi < points.count else { return nil }
        return wi
    }

    private func numericDataIndex(for slot: Int?) -> Int? {
        guard let slot, let points = chartData?.dataPoints else { return nil }
        return points.indices.first { plotSlot(forIndex: $0, label: points[$0].label) == slot }
    }

    private static let axisDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()
}
