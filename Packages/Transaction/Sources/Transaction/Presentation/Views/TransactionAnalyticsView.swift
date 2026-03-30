//
//  TransactionAnalyticsView.swift
//  Transaction
//
import Charts
import FinFlowCore
import SwiftUI

public struct TransactionAnalyticsView: View {
    private let insights: [TransactionAIInsight] = [
        TransactionAIInsight(
            id: "spending-warning",
            title: "Cảnh báo chi tiêu",
            message:
                "Bạn đã chi tiêu nhiều hơn 35% cho mục Ăn uống so với tháng trước. Hãy cân nhắc nấu ăn tại nhà để tiết kiệm khoảng 2.000.000 ₫ tháng tới.",
            icon: "exclamationmark.triangle.fill",
            color: AppColors.primary
        ),
        TransactionAIInsight(
            id: "financial-tip",
            title: "Mẹo Tài Chính",
            message:
                "Thu nhập tháng này của bạn rất tốt. Nếu bạn trích 15% (khoảng 3.750.000 ₫) vào quỹ dự phòng khẩn cấp, bạn sẽ đạt mục tiêu an toàn tài chính sớm hơn 2 tháng.",
            icon: "leaf.fill",
            color: AppColors.success
        ),
    ]

    public var summary: TransactionSummaryResponse?
    let chartData: TransactionChartResponse?
    let currentRange: ChartRange
    let onRangeChange: (ChartRange) -> Void
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void
    public var isChartLoading: Bool
    public var hasLoadError: Bool
    public var onRetry: (() -> Void)?

    @State private var selectedRange: ChartRange

    /// Tháng / quý / năm: slot số. Tuần: dùng `selectedWeekday` (trục phân loại T2…CN).
    @State private var selectedPlotSlot: Int?
    @State private var selectedWeekday: String?

    private struct ChartBarRow: Identifiable {
        let id: String
        let plotSlot: Int
        let series: String
        let amount: Double
        let dataIndex: Int
    }

    /// Tuần: trục X là **chuỗi cố định** T2→CN (categorical) để nhãn khớp cột; không dùng 1…7 kiểu số.
    private struct WeekChartBarRow: Identifiable {
        let id: String
        let weekday: String
        let series: String
        let amount: Double
        let dataIndex: Int
    }

    private static let weekdayAxisCategories: [String] = [
        "T2", "T3", "T4", "T5", "T6", "T7", "CN",
    ]

    private var mappedBarRows: [ChartBarRow] {
        guard let data = chartData else { return [] }
        return data.dataPoints.enumerated().flatMap { index, point in
            let slot = plotSlot(forDataIndex: index, label: point.label)
            return [
                ChartBarRow(
                    id: "\(slot)-thu-\(index)",
                    plotSlot: slot,
                    series: "Thu nhập",
                    amount: point.income,
                    dataIndex: index
                ),
                ChartBarRow(
                    id: "\(slot)-chi-\(index)",
                    plotSlot: slot,
                    series: "Chi tiêu",
                    amount: -point.expense,
                    dataIndex: index
                ),
            ]
        }
    }

    private var mappedWeekBarRows: [WeekChartBarRow] {
        guard let data = chartData else { return [] }
        return data.dataPoints.enumerated().flatMap { index, point in
            let day = Self.weekdayLabel(forRelativeIndex: index)
            return [
                WeekChartBarRow(
                    id: "\(day)-thu-\(index)",
                    weekday: day,
                    series: "Thu nhập",
                    amount: point.income,
                    dataIndex: index
                ),
                WeekChartBarRow(
                    id: "\(day)-chi-\(index)",
                    weekday: day,
                    series: "Chi tiêu",
                    amount: -point.expense,
                    dataIndex: index
                ),
            ]
        }
    }

    private static func weekdayLabel(forRelativeIndex index: Int) -> String {
        guard index >= 0, index < weekdayAxisCategories.count else {
            return weekdayAxisCategories[min(max(index, 0), weekdayAxisCategories.count - 1)]
        }
        return weekdayAxisCategories[index]
    }

    private var hasPlottableChartValues: Bool {
        guard let data = chartData, !data.dataPoints.isEmpty else { return false }
        return data.dataPoints.contains { $0.income != 0 || $0.expense != 0 }
    }

    public init(
        summary: TransactionSummaryResponse? = nil,
        chartData: TransactionChartResponse? = nil,
        currentRange: ChartRange = .month,
        onRangeChange: @escaping (ChartRange) -> Void,
        onNavigateBack: @escaping () -> Void,
        onNavigateForward: @escaping () -> Void,
        isChartLoading: Bool = false,
        hasLoadError: Bool = false,
        onRetry: (() -> Void)? = nil
    ) {
        self.summary = summary
        self.chartData = chartData
        self.currentRange = currentRange
        self.onRangeChange = onRangeChange
        self.onNavigateBack = onNavigateBack
        self.onNavigateForward = onNavigateForward
        self.isChartLoading = isChartLoading
        self.hasLoadError = hasLoadError
        self.onRetry = onRetry
        self._selectedRange = State(initialValue: currentRange)
    }

    public var body: some View {
        List {
            // 1. Time Range Picker
            Section {
                Picker(
                    "Thời gian",
                    selection: $selectedRange
                ) {
                    ForEach(ChartRange.allCases, id: \.rawValue) { range in
                        Text(range.fullName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, AppSpacing.xs)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // 2. Chart Section
            Section {
                chartSection
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // 3. AI Insights Section
            TransactionAnalyticsAIInsightsSection(insights: insights)

            Section {
                Button {
                    // Trigger AI Report Generation
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Tạo Báo Cáo Chi Tiết")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.insetGrouped)
        .onChange(of: currentRange) { _, newValue in
            selectedRange = newValue
        }
        .onChange(of: selectedRange) { oldValue, newValue in
            guard oldValue != newValue else { return }
            onRangeChange(newValue)
        }
        .onChange(of: selectedPlotSlot) { _, newValue in
            handleNumericSelectionChanged(newValue)
        }
        .onChange(of: selectedWeekday) { _, newValue in
            if newValue != nil {
                ChartSelectionHaptics.selectionChanged()
            }
        }
        .onChange(of: currentRange) { _, _ in
            selectedPlotSlot = nil
            selectedWeekday = nil
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppSpacing.xl * 2)
        }
    }

    // MARK: - Components

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            chartNavigationHeader
            chartContent
                .padding(.vertical, AppSpacing.sm)
        }
    }

    private var chartNavigationHeader: some View {
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

    @ViewBuilder
    private var chartContent: some View {
        if isChartLoading {
            TransactionAnalyticsChartStateView(
                icon: nil,
                title: nil,
                showProgress: true,
                hasLoadError: hasLoadError,
                onRetry: onRetry
            )
        } else if hasLoadError {
            TransactionAnalyticsChartStateView(
                icon: "wifi.exclamationmark",
                title: "Không thể tải thống kê",
                showProgress: false,
                hasLoadError: hasLoadError,
                onRetry: onRetry
            )
        } else if !hasPlottableChartValues {
            TransactionAnalyticsChartStateView(
                icon: "chart.bar.xaxis",
                title: "Chưa có dữ liệu thống kê",
                showProgress: false,
                hasLoadError: hasLoadError,
                onRetry: onRetry
            )
        } else {
            chartBarView
        }
    }

    private var chartBarView: some View {
        Group {
            if currentRange == .week {
                weekChartBarView
            } else {
                numericChartBarView
            }
        }
    }

    private var weekChartBarView: some View {
        let rows = mappedWeekBarRows
        let labelSource = chartData?.dataPoints ?? []

        return ZStack(alignment: .top) {
            Chart {
                ForEach(rows) { row in
                    BarMark(
                        x: .value("Thứ", row.weekday),
                        y: .value("Số tiền", row.amount)
                    )
                    .foregroundStyle(by: .value("Loại", row.series))
                    .opacity(
                        selectedWeekday == nil || selectedWeekday == row.weekday
                            ? 1.0 : OpacityLevel.low)
                }
            }
            .chartForegroundStyleScale([
                "Thu nhập": AppColors.success,
                "Chi tiêu": AppColors.google,
            ])
            .chartLegend(position: .top, alignment: .leading)
            .chartXScale(domain: Self.weekdayAxisCategories)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(CurrencyFormatter.formatAxisValue(abs(intValue)))
                                .font(AppTypography.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: Self.weekdayAxisCategories) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(AppTypography.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedWeekday)
            .frame(height: Layout.chartHeight)

            if let idx = selectedDataIndexForWeekday(selectedWeekday),
                idx >= 0, idx < labelSource.count
            {
                barDetailOverlay(
                    for: labelSource[idx],
                    selectedIndex: idx,
                    totalCount: labelSource.count
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22), value: selectedWeekday)
    }

    private var numericChartBarView: some View {
        let rows = mappedBarRows
        let labelSource = chartData?.dataPoints ?? []
        let tickValues = xAxisTickSlots()
        let xDomain = chartXDomainInt()

        return ZStack(alignment: .top) {
            Chart {
                ForEach(rows) { row in
                    BarMark(
                        x: .value("Kỳ", row.plotSlot),
                        y: .value("Số tiền", row.amount)
                    )
                    .foregroundStyle(by: .value("Loại", row.series))
                    .opacity(
                        selectedPlotSlot == nil || selectedPlotSlot == row.plotSlot
                            ? 1.0 : OpacityLevel.low)
                }
            }
            .chartForegroundStyleScale([
                "Thu nhập": AppColors.success,
                "Chi tiêu": AppColors.google,
            ])
            .chartLegend(position: .top, alignment: .leading)
            .chartXScale(domain: xDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(CurrencyFormatter.formatAxisValue(abs(intValue)))
                                .font(AppTypography.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: tickValues) { value in
                    AxisValueLabel {
                        if let slot = value.as(Int.self) {
                            Text(shortXAxisTickLabel(slot: slot))
                                .font(AppTypography.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedPlotSlot)
            .frame(height: Layout.chartHeight)

            if let idx = selectedDataIndex(for: selectedPlotSlot),
                idx >= 0, idx < labelSource.count
            {
                barDetailOverlay(
                    for: labelSource[idx],
                    selectedIndex: idx,
                    totalCount: labelSource.count
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22), value: selectedPlotSlot)
    }

    private func handleNumericSelectionChanged(_ newValue: Int?) {
        guard newValue != nil else { return }
        ChartSelectionHaptics.selectionChanged()
    }

    private func selectedDataIndexForWeekday(_ key: String?) -> Int? {
        guard let key,
            let wi = Self.weekdayAxisCategories.firstIndex(of: key),
            let points = chartData?.dataPoints,
            wi < points.count
        else { return nil }
        return wi
    }

    /// Trục X số (tháng / quý / năm). Tuần dùng `WeekChartBarRow` + `weekdayAxisCategories`.
    private func plotSlot(forDataIndex index: Int, label: String) -> Int {
        switch currentRange {
        case .month, .week:
            return index + 1
        case .quarter, .year:
            if let date = Self.chartAxisLabelDateFormatter.date(from: label) {
                return Calendar(identifier: .gregorian).component(.month, from: date)
            }
            return index + 1
        }
    }

    private func chartXDomainInt() -> ClosedRange<Int> {
        guard let points = chartData?.dataPoints, !points.isEmpty else { return 1 ... 1 }
        switch currentRange {
        case .month:
            return 1 ... points.count
        case .week:
            return 1 ... 1
        case .quarter, .year:
            let slots = points.enumerated().map { plotSlot(forDataIndex: $0.offset, label: $0.element.label) }
            let lo = slots.min() ?? 1
            let hi = slots.max() ?? 1
            return lo ... hi
        }
    }

    private func xAxisTickSlots() -> [Int] {
        guard let points = chartData?.dataPoints, !points.isEmpty else { return [] }
        let n = points.count
        let step = xAxisLabelStride(for: currentRange, dayCount: n)
        switch currentRange {
        case .month:
            return Array(stride(from: 1, through: n, by: step))
        case .week:
            return Array(1 ... 7)
        case .quarter, .year:
            let slots = (0 ..< n).map { plotSlot(forDataIndex: $0, label: points[$0].label) }
            return (0 ..< n).filter { $0 % step == 0 }.map { slots[$0] }
        }
    }

    private func selectedDataIndex(for slot: Int?) -> Int? {
        guard let slot, let points = chartData?.dataPoints else { return nil }
        for i in points.indices {
            if plotSlot(forDataIndex: i, label: points[i].label) == slot {
                return i
            }
        }
        return nil
    }

    private func shortXAxisTickLabel(slot: Int) -> String {
        "\(slot)"
    }

    /// Tháng: nhảy vài ngày trên trục để không chồng chữ (cột vẫn mỗi ngày một cặp bar).
    private func xAxisLabelStride(for range: ChartRange, dayCount: Int) -> Int {
        switch range {
        case .month:
            // ~10 nhãn cho tháng dài; tối thiểu 2 ngày/lần để dễ đọc.
            if dayCount <= 15 { return 2 }
            if dayCount <= 22 { return 3 }
            return 4
        case .week, .quarter, .year:
            return 1
        }
    }

    private static let chartAxisLabelDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    // MARK: - Bar Detail Overlay

    private func barDetailOverlay(
        for dataPoint: TransactionChartResponse.ChartDataPoint,
        selectedIndex: Int,
        totalCount: Int
    ) -> some View {
        let ratio = Double(selectedIndex) / Double(max(totalCount - 1, 1))

        return HStack(spacing: AppSpacing.xs * 0) {
            if ratio > 0.34 {
                Spacer(minLength: 0)
            }

            ChartSelectionPopover(
                title: dataPoint.label,
                subtitle: "Giữ và kéo để xem kỳ khác",
                metrics: [
                    ChartPopoverMetric(
                        id: "income",
                        label: "Thu",
                        value: CurrencyFormatter.format(dataPoint.income),
                        color: AppColors.success),
                    ChartPopoverMetric(
                        id: "expense",
                        label: "Chi",
                        value: CurrencyFormatter.format(dataPoint.expense),
                        color: AppColors.google),
                    ChartPopoverMetric(
                        id: "balance",
                        label: "Chênh lệch",
                        value: CurrencyFormatter.format(dataPoint.income - dataPoint.expense),
                        color: dataPoint.income - dataPoint.expense >= 0
                            ? AppColors.success : AppColors.google),
                ]
            )
            .frame(maxWidth: 290)

            if ratio < 0.66 {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }
}
