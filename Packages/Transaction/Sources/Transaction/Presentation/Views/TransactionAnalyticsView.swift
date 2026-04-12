//
//  TransactionAnalyticsView.swift
//  Transaction
//
import Charts
import FinFlowCore
import SwiftUI

public struct TransactionAnalyticsView: View {
    public var summary: TransactionSummaryResponse?
    let insights: [TransactionAIInsight]
    let chartData: TransactionChartResponse?
    let currentRange: ChartRange
    let onRangeChange: (ChartRange) -> Void
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void
    public var isChartLoading: Bool
    public var hasLoadError: Bool
    public var onRetry: (() -> Void)?
    public var onGenerateReport: (() -> Void)?

    @State private var selectedRange: ChartRange

    public init(
        summary: TransactionSummaryResponse? = nil,
        insights: [TransactionAIInsight] = [],
        chartData: TransactionChartResponse? = nil,
        currentRange: ChartRange = .month,
        onRangeChange: @escaping (ChartRange) -> Void,
        onNavigateBack: @escaping () -> Void,
        onNavigateForward: @escaping () -> Void,
        isChartLoading: Bool = false,
        hasLoadError: Bool = false,
        onRetry: (() -> Void)? = nil,
        onGenerateReport: (() -> Void)? = nil
    ) {
        self.summary = summary
        self.insights = insights
        self.chartData = chartData
        self.currentRange = currentRange
        self.onRangeChange = onRangeChange
        self.onNavigateBack = onNavigateBack
        self.onNavigateForward = onNavigateForward
        self.isChartLoading = isChartLoading
        self.hasLoadError = hasLoadError
        self.onRetry = onRetry
        self.onGenerateReport = onGenerateReport
        self._selectedRange = State(initialValue: currentRange)
    }

    public var body: some View {
        List {
            // 1. Time Range Picker
            Section {
                Picker("Thời gian", selection: $selectedRange) {
                    ForEach(ChartRange.allCases, id: \.rawValue) { range in
                        Text(range.fullName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, AppSpacing.xs)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // 2. Interactive Bar Chart
            Section {
                TransactionBarChartSection(
                    chartData: chartData,
                    currentRange: currentRange,
                    isChartLoading: isChartLoading,
                    hasLoadError: hasLoadError,
                    onNavigateBack: onNavigateBack,
                    onNavigateForward: onNavigateForward,
                    onRetry: onRetry
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // 3. AI Insights
            TransactionAnalyticsAIInsightsSection(insights: insights)

            // 4. Generate Report
            Section {
                Button {
                    onGenerateReport?()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Tạo Báo Cáo Chi Tiết").fontWeight(.semibold)
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
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppSpacing.xl * 2)
        }
    }
}
