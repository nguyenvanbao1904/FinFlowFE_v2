import Charts
import FinFlowCore
import SwiftUI

struct BankIncomeStructure: View {
    let items: [BankFinancialDataPoint]
    let showQuarterly: Bool
    @State private var showFullscreen = false
    @State private var hasInitializedScroll = false
    @State private var chartScrollPosition: String = ""
    @State private var selectedPeriod: String?
    @State private var displayedPeriod: String?
    @State private var hidePopoverTask: Task<Void, Never>?

    private var yearlyItems: [BankFinancialDataPoint] {
        latestUniqueByYear(items, year: \.year)
    }

    private var totalIncomeSeries: [(year: Int, value: Double)] {
        yearlyItems.compactMap { item in
            let parts = [item.netInterestIncome, item.feeAndCommissionIncome, item.otherIncome].compactMap { $0 }
            guard !parts.isEmpty else { return nil }
            return (item.year, parts.reduce(0, +))
        }
    }
    private var cagrValue: Double? { cagr(from: totalIncomeSeries) }
    private var years: [Int] { yearlyItems.map(\.year).sorted() }

    private var orderedPeriods: [String] {
        years.map { periodLabel(for: $0, showQuarterly: showQuarterly) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Cơ cấu TOI")
                        .font(AppTypography.headline)
                    if let c = cagrValue {
                        Text("Tăng trưởng kép \(String(format: "%.2f", c))%/năm")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                GrowthBadge(value: cagrValue)
                zoomButton
            }

            chart(fullScreen: false)
                .frame(height: Layout.chartHeight)

            Text(
                showQuarterly
                    ? "Chế độ Quý: hiện hiển thị mốc Q4 theo dữ liệu năm, vuốt ngang để xem thêm."
                    : "Mặc định hiển thị dữ liệu gần nhất, vuốt ngang để xem thêm."
            )
            .font(AppTypography.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppSpacing.lg)
        .padding(.horizontal, AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .onAppear {
            initializeScrollIfNeeded()
        }
        .onChange(of: selectedPeriod) { oldValue, newValue in
            handleSelectionChanged(from: oldValue, to: newValue)
        }
        .onDisappear {
            hidePopoverTask?.cancel(); hidePopoverTask = nil
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            ChartFullscreenContainer(title: "Cơ cấu TOI") {
                GeometryReader { proxy in
                    chart(fullScreen: true)
                        .frame(maxWidth: .infinity)
                        .frame(height: ChartFullscreenSupport.preferredChartHeight(for: proxy.size))
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                }
            }
        }
    }

    private var zoomButton: some View {
        Button {
            showFullscreen = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(AppTypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.primary)
                .frame(width: 28, height: 28)
                .background(AppColors.primary.opacity(0.1))
                .clipShape(Circle())
        }
        .accessibilityLabel("Phóng to biểu đồ")
    }

    private func chart(fullScreen: Bool) -> some View {
        let displayItems = yearlyItems
        let visibleLength = fullScreen ? min(6, max(1, years.count)) : min(3, max(1, years.count))

        let baseChart = Chart {
            ForEach(displayItems) { item in
                if let v = item.netInterestIncome {
                    BarMark(
                        x: .value("Kỳ", periodLabel(for: item.year, showQuarterly: showQuarterly)),
                        y: .value("Giá trị", v),
                        width: .fixed(26)
                    )
                    .foregroundStyle(by: .value("Loại", "Thu nhập lãi thuần"))
                }

                if let v = item.feeAndCommissionIncome {
                    BarMark(
                        x: .value("Kỳ", periodLabel(for: item.year, showQuarterly: showQuarterly)),
                        y: .value("Giá trị", v),
                        width: .fixed(26)
                    )
                    .foregroundStyle(by: .value("Loại", "Lãi thuần hoạt động dịch vụ"))
                }

                if let v = item.otherIncome {
                    BarMark(
                        x: .value("Kỳ", periodLabel(for: item.year, showQuarterly: showQuarterly)),
                        y: .value("Giá trị", v),
                        width: .fixed(26)
                    )
                    .foregroundStyle(by: .value("Loại", "Thu nhập hoạt động khác"))
                }
            }
        }
        .chartForegroundStyleScale([
            "Thu nhập lãi thuần": AppColors.chartIncomeInterest,
            "Lãi thuần hoạt động dịch vụ": AppColors.chartIncomeFee,
            "Thu nhập hoạt động khác": AppColors.chartIncomeOther,
        ])
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel()
            }
        }
        .chartXAxis {
            periodAxis(
                values: uniqueOrdered(
                    displayItems.map { periodLabel(for: $0.year, showQuarterly: showQuarterly) })
            )
        }
        .chartLegend(position: .bottom)

        return AnyView(
            ZStack(alignment: .top) {
                baseChart
                    .chartXScale(domain: chartPlottableStringPeriodDomain(orderPreserving: orderedPeriods))
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: visibleLength)
                    .chartScrollPosition(x: $chartScrollPosition)
                    .chartXSelection(value: $selectedPeriod)

                if let displayedPeriod {
                    selectionPopover(for: displayedPeriod)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.xs)
                }
            }
        )
    }

    private func initializeScrollIfNeeded() {
        guard !hasInitializedScroll else { return }
        let startIndex = max(orderedPeriods.count - 3, 0)
        chartScrollPosition =
            orderedPeriods.indices.contains(startIndex)
            ? orderedPeriods[startIndex] : ""
        hasInitializedScroll = true
    }

    @ViewBuilder
    private func selectionPopover(for period: String) -> some View {
        if let selectedYear = years.first(where: {
            periodLabel(for: $0, showQuarterly: showQuarterly) == period
        }),
            let selectedItem = yearlyItems.first(where: { $0.year == selectedYear })
        {
            let index = orderedPeriods.firstIndex(of: period) ?? 0
            let ratio = Double(index) / Double(max(orderedPeriods.count - 1, 1))

            let _ = selectedItem
            let _ = ratio
            EmptyView()
        }
    }

    private func handleSelectionChanged(from oldValue: String?, to newValue: String?) {
        nativeSelectionChange(to: newValue, displayedValue: &displayedPeriod)
    }
}
