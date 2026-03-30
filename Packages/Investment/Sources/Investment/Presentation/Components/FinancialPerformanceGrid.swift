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

func latestUniqueByYear<T>(_ items: [T], year: KeyPath<T, Int>) -> [T] {
    var latestByYear: [Int: T] = [:]
    for item in items {
        latestByYear[item[keyPath: year]] = item
    }
    return latestByYear.values.sorted { $0[keyPath: year] < $1[keyPath: year] }
}

func yearlyRevenues(_ data: FinancialDataSeries) -> [(year: Int, value: Double)] {
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

func yearlyProfits(_ data: FinancialDataSeries) -> [(year: Int, value: Double)] {
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

func cagr(from series: [(year: Int, value: Double)]) -> Double? {
    guard let first = series.first, let last = series.last,
        first.value > 0, last.value > 0,
        last.year > first.year
    else { return nil }
    let n = Double(last.year - first.year)
    return (pow(last.value / first.value, 1.0 / n) - 1.0) * 100
}

func axisYearLabel(for year: Int, showQuarterly: Bool) -> String {
    guard showQuarterly else { return String(year) }
    return "Q4\n\(year % 100)"
}

func periodLabel(for year: Int, showQuarterly: Bool) -> String {
    guard showQuarterly else { return String(year) }
    return "Q4/\(year % 100)"
}

func chartVisibleLength(fullScreen: Bool, pointCount: Int) -> Int {
    fullScreen ? max(1, pointCount) : min(3, max(1, pointCount))
}

func yearAxis(values: [Int], showQuarterly: Bool) -> some AxisContent {
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

func periodAxis(values: [String]) -> some AxisContent {
    AxisMarks(values: values) { value in
        AxisGridLine().foregroundStyle(AppColors.chartGridLine)
        AxisValueLabel {
            if let label = value.as(String.self) {
                Text(label).font(AppTypography.caption2)
            }
        }
    }
}

func uniqueOrdered(_ values: [String]) -> [String] {
    var seen: Set<String> = []
    return values.filter { seen.insert($0).inserted }
}

/// Trục X (String) với 0–1 phần tử làm Charts crash: *Linear scale domain must contain two values*.
func chartPlottableStringPeriodDomain(orderPreserving periods: [String]) -> [String] {
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


func nativeSelectionChange(to newValue: String?, displayedValue: inout String?) {
    displayedValue = newValue
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

// MARK: - Shared Components

struct GrowthBadge: View {
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

struct LegendItem: View {
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
