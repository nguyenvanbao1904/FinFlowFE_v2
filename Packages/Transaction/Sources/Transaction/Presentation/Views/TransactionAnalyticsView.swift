//
//  TransactionAnalyticsView.swift
//  Transaction
//
// swiftlint:disable file_length
// Justification: Analytics screen with chart visualization, error states, and AI insights.
// Components are tightly coupled to chart data. Well-structured with MARK sections.

import Charts
import FinFlowCore
import SwiftUI

public struct TransactionAnalyticsView: View {
    public var summary: TransactionSummaryResponse?
    let chartData: TransactionChartResponse?
    let currentRange: ChartRange
    let onRangeChange: (ChartRange) -> Void
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void
    public var isLoading: Bool
    public var hasLoadError: Bool
    public var onRetry: (() -> Void)?

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
        var result: [ChartItem] = []
        for (index, point) in data.dataPoints.enumerated() {
            result.append(
                ChartItem(index: index, period: point.label, type: "Thu nhập", amount: point.income)
            )
            result.append(
                ChartItem(
                    index: index, period: point.label, type: "Chi tiêu", amount: -point.expense)
            )
        }
        return result
    }

    public init(
        summary: TransactionSummaryResponse? = nil,
        chartData: TransactionChartResponse? = nil,
        currentRange: ChartRange = .month,
        onRangeChange: @escaping (ChartRange) -> Void,
        onNavigateBack: @escaping () -> Void,
        onNavigateForward: @escaping () -> Void,
        isLoading: Bool = false,
        hasLoadError: Bool = false,
        onRetry: (() -> Void)? = nil
    ) {
        self.summary = summary
        self.chartData = chartData
        self.currentRange = currentRange
        self.onRangeChange = onRangeChange
        self.onNavigateBack = onNavigateBack
        self.onNavigateForward = onNavigateForward
        self.isLoading = isLoading
        self.hasLoadError = hasLoadError
        self.onRetry = onRetry
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                // 1. Time Range Picker
                Picker(
                    "Thời gian",
                    selection: Binding<ChartRange>(
                        get: { currentRange },
                        set: { onRangeChange($0) }
                    )
                ) {
                    ForEach(ChartRange.allCases, id: \.rawValue) { range in
                        Text(range.fullName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // 2. Chart Section
                chartSection

                // 3. AI Insights Section
                aiInsightsSection

                // Bottom padding to avoid tab bar collision
                Color.clear.frame(height: 100)
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Components

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            chartNavigationHeader
            chartContent
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.large)
                .padding(.horizontal)
        }
    }

    private var chartNavigationHeader: some View {
        let canGoForward = chartData?.hasNext ?? false
        return HStack {
            Button(action: onNavigateBack) {
                Image(systemName: "chevron.left")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.primary)
            }
            Spacer()
            Text(chartData?.periodLabel ?? "Biến động Số Dư")
                .font(AppTypography.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: onNavigateForward) {
                Image(systemName: "chevron.right")
                    .font(AppTypography.body)
                    .foregroundColor(
                        canGoForward ? AppColors.primary : .secondary.opacity(OpacityLevel.low))
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var chartContent: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 250)
        } else if hasLoadError {
            chartErrorView
        } else if mappedData.isEmpty || mappedData.allSatisfy({ $0.amount == 0 }) {
            chartEmptyView
        } else {
            chartBarView
        }
    }

    private var chartErrorView: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(AppTypography.displayLarge)
                .foregroundColor(.secondary.opacity(OpacityLevel.strong))
            Text("Không thể tải thống kê")
                .font(AppTypography.body)
                .foregroundColor(.secondary)
            if let onRetry = onRetry {
                Button("Thử lại") { onRetry() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }

    private var chartEmptyView: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(AppTypography.displayLarge)
                .foregroundColor(.secondary.opacity(OpacityLevel.strong))
            Text("Chưa có dữ liệu thống kê")
                .font(AppTypography.body)
                .foregroundColor(.secondary)
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
                        if let idx = value.as(Int.self),
                            idx >= 0,
                            idx < labelSource.count {
                            Text(labelSource[idx].label)
                                .font(AppTypography.caption)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedBarIndex)
            .frame(height: Layout.chartHeight)

            // Dimmed background overlay when bar is selected
            if selectedBarIndex != nil {
                Color.black.opacity(OpacityLevel.light)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedBarIndex = nil
                        }
                    }
                    .transition(.opacity)
            }

            // Detail overlay when bar is selected
            if let selectedIndex = selectedBarIndex,
                selectedIndex >= 0,
                selectedIndex < labelSource.count {
                barDetailOverlay(for: labelSource[selectedIndex])
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func xAxisStride() -> Int {
        switch currentRange {
        case .week:
            return 1
        case .month:
            return 5
        case .quarter, .year:
            return 1
        }
    }

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.accent)
                Text("Trợ lý AI Phân Tích")
                    .font(AppTypography.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: Spacing.md) {
                // Insight 1
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Circle()
                        .fill(AppColors.primary.opacity(OpacityLevel.light))
                        .frame(width: Spacing.iconMedium, height: Spacing.iconMedium)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.primary)
                                .font(AppTypography.caption)
                        }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Cảnh báo chi tiêu")
                            .font(AppTypography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text(
                            "Bạn đã chi tiêu nhiều hơn 35% cho mục Ăn uống so với tháng trước. Hãy cân nhắc nấu ăn tại nhà để tiết kiệm khoảng 2.000.000 ₫ tháng tới."
                        )
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                        .lineSpacing(Spacing.xs / 2)
                    }
                }

                Divider().background(AppColors.disabled.opacity(OpacityLevel.strong))

                // Insight 2
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Circle()
                        .fill(AppColors.success.opacity(OpacityLevel.light))
                        .frame(width: Spacing.iconMedium, height: Spacing.iconMedium)
                        .overlay {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(AppColors.success)
                                .font(AppTypography.caption)
                        }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Mẹo Tài Chính")
                            .font(AppTypography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text(
                            "Thu nhập tháng này của bạn rất tốt. Nếu bạn trích 15% (khoảng 3.750.000 ₫) vào quỹ dự phòng khẩn cấp, bạn sẽ đạt mục tiêu an toàn tài chính sớm hơn 2 tháng."
                        )
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                        .lineSpacing(Spacing.xs / 2)
                    }
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.large)
            .padding(.horizontal)

            // Generate Detailed Report Button
            Button {
                // Trigger AI Report Generation
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Tạo Báo Cáo Chi Tiết")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.primary.opacity(OpacityLevel.light))
                .foregroundColor(AppColors.primary)
                .cornerRadius(CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            AppColors.primary.opacity(OpacityLevel.strong),
                            lineWidth: BorderWidth.thin)
                )
            }
            .padding(.horizontal)
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Bar Detail Overlay

    private func barDetailOverlay(for dataPoint: TransactionChartResponse.ChartDataPoint)
        -> some View {
        VStack(spacing: Spacing.xs) {
            // Date/Period label - minimal and centered
            Text(dataPoint.label)
                .font(AppTypography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Income and Expense side by side
            HStack(spacing: Spacing.md) {
                // Income
                VStack(spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.success)
                        Text("Thu")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(CurrencyFormatter.format(dataPoint.income))
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.success)
                }
                .frame(maxWidth: .infinity)

                // Vertical divider
                Rectangle()
                    .fill(.secondary.opacity(OpacityLevel.light))
                    .frame(width: BorderWidth.thin, height: Spacing.iconMedium + Spacing.xs)

                // Expense
                VStack(spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.google)
                        Text("Chi")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(CurrencyFormatter.format(dataPoint.expense))
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.google)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(AppColors.cardBackground)
                .shadow(color: .black.opacity(OpacityLevel.ultraLight), radius: 8, y: 2)
        )
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xs)
    }
}

// Mock Data Model
struct ExpenseData: Identifiable {
    let id = UUID()
    let period: String
    let amount: Double
}

#Preview {
    ZStack {
        AppColors.appBackground
            .ignoresSafeArea()
        TransactionAnalyticsView(
            summary: nil,
            chartData: nil,
            currentRange: .month,
            onRangeChange: { _ in },
            onNavigateBack: {},
            onNavigateForward: {},
            isLoading: false,
            hasLoadError: false,
            onRetry: nil
        )
    }
}
