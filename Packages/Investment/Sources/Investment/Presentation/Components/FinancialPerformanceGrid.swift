import Charts
import FinFlowCore
import SwiftUI

// swiftlint:disable file_length

public struct FinancialPerformanceGrid: View {
    let financials: FinancialDataSeries?
    let showQuarterly: Bool

    public init(financials: FinancialDataSeries?, showQuarterly: Bool = false) {
        self.financials = financials
        self.showQuarterly = showQuarterly
    }

    public var body: some View {
        VStack {
            if let data = financials {
                RevenueGrowthChart(financials: data, showQuarterly: showQuarterly)
                ProfitGrowthChart(financials: data, showQuarterly: showQuarterly)
                IncomeStructureChart(financials: data, showQuarterly: showQuarterly)
            }
        }
    }
}

// MARK: - Helpers

private func latestUniqueByYear<T>(_ items: [T], year: KeyPath<T, Int>) -> [T] {
    var latestByYear: [Int: T] = [:]
    for item in items {
        latestByYear[item[keyPath: year]] = item
    }
    return latestByYear.values.sorted { $0[keyPath: year] < $1[keyPath: year] }
}

private func yearlyRevenues(_ data: FinancialDataSeries) -> [(year: Int, value: Double)] {
    switch data {
    case .bank(let items):
        return latestUniqueByYear(items, year: \.year).compactMap { item in
            let parts = [item.netInterestIncome, item.feeAndCommissionIncome, item.otherIncome].compactMap { $0 }
            guard !parts.isEmpty else { return nil }
            return (item.year, parts.reduce(0, +))
        }
    case .nonBank(let items):
        return latestUniqueByYear(items, year: \.year).compactMap { item in
            guard let value = item.netRevenue else { return nil }
            return (item.year, value)
        }
    }
}

private func yearlyProfits(_ data: FinancialDataSeries) -> [(year: Int, value: Double)] {
    switch data {
    case .bank(let items):
        return latestUniqueByYear(items, year: \.year).compactMap { item in
            guard let value = item.profitAfterTax else { return nil }
            return (item.year, value)
        }
    case .nonBank(let items):
        return latestUniqueByYear(items, year: \.year).compactMap { item in
            guard let value = item.profitAfterTax else { return nil }
            return (item.year, value)
        }
    }
}

private func cagr(from series: [(year: Int, value: Double)]) -> Double? {
    guard let first = series.first, let last = series.last,
        first.value > 0, last.value > 0,
        last.year > first.year
    else { return nil }
    let n = Double(last.year - first.year)
    return (pow(last.value / first.value, 1.0 / n) - 1.0) * 100
}

private func axisYearLabel(for year: Int, showQuarterly: Bool) -> String {
    guard showQuarterly else { return String(year) }
    return "Q4\n\(year % 100)"
}

private func periodLabel(for year: Int, showQuarterly: Bool) -> String {
    guard showQuarterly else { return String(year) }
    return "Q4/\(year % 100)"
}

private func chartVisibleLength(fullScreen: Bool, pointCount: Int) -> Int {
    fullScreen ? max(1, pointCount) : min(3, max(1, pointCount))
}

private func yearAxis(values: [Int], showQuarterly: Bool) -> some AxisContent {
    AxisMarks(values: values) { value in
        AxisGridLine().foregroundStyle(AppColors.chartGridLine)
        AxisValueLabel {
            if let year = value.as(Int.self) {
                Text(axisYearLabel(for: year, showQuarterly: showQuarterly)).font(
                    AppTypography.caption2)
            } else if let year = value.as(Double.self) {
                Text(axisYearLabel(for: Int(year), showQuarterly: showQuarterly)).font(
                    AppTypography.caption2)
            }
        }
    }
}

private func periodAxis(values: [String]) -> some AxisContent {
    AxisMarks(values: values) { value in
        AxisGridLine().foregroundStyle(AppColors.chartGridLine)
        AxisValueLabel {
            if let label = value.as(String.self) {
                Text(label).font(AppTypography.caption2)
            }
        }
    }
}

private func uniqueOrdered(_ values: [String]) -> [String] {
    var seen: Set<String> = []
    return values.filter { seen.insert($0).inserted }
}

/// Trục X (String) với 0–1 phần tử làm Charts crash: *Linear scale domain must contain two values*.
private func chartPlottableStringPeriodDomain(orderPreserving periods: [String]) -> [String] {
    let orderedUnique = uniqueOrdered(periods)
    if orderedUnique.count >= 2 {
        return orderedUnique
    }
    if orderedUnique.isEmpty {
        return ["—", "—\u{200C}"]
    }
    let only = orderedUnique[0]
    return [only, only + "\u{200C}"]
}


private func nativeSelectionChange(to newValue: String?, displayedValue: inout String?) {
    displayedValue = newValue
}

// MARK: - Revenue Growth Chart

private struct RevenueGrowthChart: View {
    let financials: FinancialDataSeries
    let showQuarterly: Bool
    @State private var showFullscreen = false
    @State private var hasInitializedScroll = false
    @State private var chartScrollPosition: String = ""
    @State private var selectedPeriod: String?
    @State private var displayedPeriod: String?
    @State private var hidePopoverTask: Task<Void, Never>?

    private var revenues: [(year: Int, value: Double)] { yearlyRevenues(financials) }
    private var cagrValue: Double? { cagr(from: revenues) }
    private var years: [Int] { revenues.map(\.year).sorted() }

    private var orderedPeriods: [String] {
        years.map { periodLabel(for: $0, showQuarterly: showQuarterly) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Doanh thu hàng năm")
                        .font(AppTypography.headline)
                    if let c = cagrValue {
                        Text(
                            "Tăng trưởng kép \(String(format: "%.2f", c))%/năm trong \(revenues.count) năm qua"
                        )
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
            ChartFullscreenContainer(title: "Doanh thu hàng năm") {
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
        let displayData = revenues
        let visibleLength = fullScreen ? min(6, max(1, years.count)) : min(3, max(1, years.count))

        let baseChart = Chart {
            ForEach(displayData, id: \.year) { item in
                BarMark(
                    x: .value("Kỳ", periodLabel(for: item.year, showQuarterly: showQuarterly)),
                    y: .value("Doanh thu", item.value),
                    width: .fixed(28)
                )
                .foregroundStyle(AppColors.chartRevenue.gradient)
                .cornerRadius(3)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel()
            }
        }
        .chartXAxis {
            periodAxis(
                values: uniqueOrdered(
                    displayData.map { periodLabel(for: $0.year, showQuarterly: showQuarterly) }))
        }
        .chartLegend(position: .top) {
            LegendItem(color: AppColors.chartRevenue, label: "Doanh thu")
        }

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
            let selectedValue = revenues.first(where: { $0.year == selectedYear })?.value
        {
            let index = orderedPeriods.firstIndex(of: period) ?? 0
            let ratio = Double(index) / Double(max(orderedPeriods.count - 1, 1))

            EmptyView()
        }
    }

    private func handleSelectionChanged(from oldValue: String?, to newValue: String?) {
        nativeSelectionChange(to: newValue, displayedValue: &displayedPeriod)
    }
}

// MARK: - Profit Growth Chart

private struct ProfitGrowthChart: View {
    let financials: FinancialDataSeries
    let showQuarterly: Bool
    @State private var showFullscreen = false
    @State private var hasInitializedScroll = false
    @State private var chartScrollPosition: String = ""
    @State private var selectedPeriod: String?
    @State private var displayedPeriod: String?
    @State private var hidePopoverTask: Task<Void, Never>?

    private var profits: [(year: Int, value: Double)] { yearlyProfits(financials) }
    private var cagrValue: Double? { cagr(from: profits) }
    private var years: [Int] { profits.map(\.year).sorted() }

    private var orderedPeriods: [String] {
        years.map { periodLabel(for: $0, showQuarterly: showQuarterly) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Lợi nhuận hàng năm")
                        .font(AppTypography.headline)
                    if let c = cagrValue {
                        Text(
                            "Tăng trưởng kép \(String(format: "%.2f", c))%/năm trong \(profits.count) năm qua"
                        )
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
            ChartFullscreenContainer(title: "Lợi nhuận hàng năm") {
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
        let displayData = profits
        let visibleLength = fullScreen ? min(6, max(1, years.count)) : min(3, max(1, years.count))

        let baseChart = Chart {
            ForEach(displayData, id: \.year) { item in
                BarMark(
                    x: .value("Kỳ", periodLabel(for: item.year, showQuarterly: showQuarterly)),
                    y: .value("Lợi nhuận", item.value),
                    width: .fixed(28)
                )
                .foregroundStyle(AppColors.chartProfit.gradient)
                .cornerRadius(3)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel()
            }
        }
        .chartXAxis {
            periodAxis(
                values: uniqueOrdered(
                    displayData.map { periodLabel(for: $0.year, showQuarterly: showQuarterly) }))
        }
        .chartLegend(position: .top) {
            LegendItem(color: AppColors.chartProfit, label: "Lợi nhuận")
        }

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
            let selectedValue = profits.first(where: { $0.year == selectedYear })?.value
        {
            let index = orderedPeriods.firstIndex(of: period) ?? 0
            let ratio = Double(index) / Double(max(orderedPeriods.count - 1, 1))

            EmptyView()
        }
    }

    private func handleSelectionChanged(from oldValue: String?, to newValue: String?) {
        nativeSelectionChange(to: newValue, displayedValue: &displayedPeriod)
    }
}

// MARK: - Income Structure Chart (TOI Breakdown)

private struct IncomeStructureChart: View {
    let financials: FinancialDataSeries
    let showQuarterly: Bool

    var body: some View {
        switch financials {
        case .bank(let items):
            BankIncomeStructure(items: items, showQuarterly: showQuarterly)
        case .nonBank:
            EmptyView()
        }
    }
}

private struct BankIncomeStructure: View {
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

            EmptyView()
        }
    }

    private func handleSelectionChanged(from oldValue: String?, to newValue: String?) {
        nativeSelectionChange(to: newValue, displayedValue: &displayedPeriod)
    }
}

// MARK: - Shared Components

private struct GrowthBadge: View {
    let value: Double?

    var body: some View {
        if let v = value {
            Text(v >= 10 ? "Tăng trưởng cao" : "Tăng trưởng ổn định")
                .font(AppTypography.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(
                    v >= 10 ? AppColors.chartGrowthStrong : AppColors.chartGrowthStable
                )
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    (v >= 10 ? AppColors.chartGrowthStrong : AppColors.chartGrowthStable).opacity(
                        0.15)
                )
                .clipShape(Capsule())
        }
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
                .font(AppTypography.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
