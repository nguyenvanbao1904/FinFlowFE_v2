//
//  TransactionAnalyticsView.swift
//  Transaction
//
import Charts
import FinFlowCore
import SwiftUI

public struct TransactionAnalyticsView: View {
    private struct AIInsight: Identifiable {
        let id: String
        let title: String
        let message: String
        let icon: String
        let color: Color
    }

    private let insights: [AIInsight] = [
        AIInsight(
            id: "spending-warning",
            title: "Cảnh báo chi tiêu",
            message:
                "Bạn đã chi tiêu nhiều hơn 35% cho mục Ăn uống so với tháng trước. Hãy cân nhắc nấu ăn tại nhà để tiết kiệm khoảng 2.000.000 ₫ tháng tới.",
            icon: "exclamationmark.triangle.fill",
            color: AppColors.primary
        ),
        AIInsight(
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

    // State for selected bar
    @State private var selectedBarIndex: Int?

    struct ChartItem: Identifiable {
        let id = UUID()
        let index: Int
        let period: String
        let type: String
        let amount: Double
    }

    var mappedData: [ChartItem] {
        guard let data = chartData else { return [] }
        return data.dataPoints.enumerated().flatMap { index, point in
            [
                ChartItem(
                    index: index, period: point.label, type: "Thu nhập", amount: point.income),
                ChartItem(
                    index: index, period: point.label, type: "Chi tiêu", amount: -point.expense),
            ]
        }
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
            aiInsightsSection

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
        .onChange(of: selectedBarIndex) { _, newValue in
            handleSelectionChanged(newValue)
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
                    .foregroundColor(AppColors.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(isChartLoading)
            .buttonStyle(.plain)
            Spacer()
            Text(chartData?.periodLabel ?? "Biến động Số Dư")
                .font(AppTypography.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: onNavigateForward) {
                Image(systemName: "chevron.right")
                    .font(AppTypography.body)
                    .foregroundColor(
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
            chartStateView(icon: nil, title: nil, showProgress: true)
        } else if hasLoadError {
            chartStateView(icon: "wifi.exclamationmark", title: "Không thể tải thống kê")
        } else if mappedData.isEmpty || mappedData.allSatisfy({ $0.amount == 0 }) {
            chartStateView(icon: "chart.bar.xaxis", title: "Chưa có dữ liệu thống kê")
        } else {
            chartBarView
        }
    }

    @ViewBuilder
    private func chartStateView(icon: String?, title: String?, showProgress: Bool = false)
        -> some View
    {
        VStack(spacing: AppSpacing.sm) {
            if showProgress {
                ProgressView()
            } else {
                if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.displayLarge)
                        .foregroundColor(.secondary.opacity(OpacityLevel.strong))
                }
                if let title {
                    Text(title)
                        .font(AppTypography.body)
                        .foregroundColor(.secondary)
                }
                if hasLoadError, let onRetry {
                    Button("Thử lại") { onRetry() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }

    private var chartBarView: some View {
        let data = mappedData
        let stride = xAxisStride()
        let labelSource = chartData?.dataPoints ?? []

        return ZStack(alignment: .top) {
            Chart {
                ForEach(data) { item in
                    BarMark(
                        x: .value("Index", item.index),
                        y: .value("Số tiền", item.amount)
                    )
                    .foregroundStyle(
                        item.type == "Thu nhập"
                            ? AppColors.success
                            : AppColors.google
                    )
                    .opacity(
                        selectedBarIndex == nil || selectedBarIndex == item.index
                            ? 1.0 : OpacityLevel.low)
                }
            }
            .chartLegend(position: .top, alignment: .leading)
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
                AxisMarks(values: .stride(by: Double(stride))) { value in
                    AxisValueLabel {
                        if let idx = value.as(Int.self), idx >= 0, idx < labelSource.count {
                            Text(labelSource[idx].label)
                                .font(AppTypography.caption)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedBarIndex)
            .frame(height: Layout.chartHeight)

            // Detail overlay when bar is selected
            if let selectedIndex = selectedBarIndex, selectedIndex >= 0,
                selectedIndex < labelSource.count
            {
                barDetailOverlay(
                    for: labelSource[selectedIndex],
                    selectedIndex: selectedIndex,
                    totalCount: labelSource.count
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22), value: selectedBarIndex)
    }

    private func handleSelectionChanged(_ newValue: Int?) {
        guard newValue != nil else { return }
        ChartSelectionHaptics.selectionChanged()
    }

    private func xAxisStride() -> Int {
        currentRange == .month ? 5 : 1
    }

    @ViewBuilder
    private var aiInsightsSection: some View {
        Section {
            ForEach(insights) { insight in
                insightRow(insight)
                    .padding(.vertical, AppSpacing.xs)
            }
        } header: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.accent)
                Text("Trợ lý AI Phân Tích")
                    .font(AppTypography.headline)
                    .foregroundColor(.primary)
            }
            .textCase(nil)
        }
    }

    private func insightRow(_ insight: AIInsight) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Circle()
                .fill(insight.color.opacity(OpacityLevel.light))
                .frame(width: AppSpacing.iconMedium, height: AppSpacing.iconMedium)
                .overlay {
                    Image(systemName: insight.icon)
                        .foregroundColor(insight.color)
                        .font(AppTypography.caption)
                }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(insight.title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(insight.message)
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(AppSpacing.xs / 2)
            }
        }
    }

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
