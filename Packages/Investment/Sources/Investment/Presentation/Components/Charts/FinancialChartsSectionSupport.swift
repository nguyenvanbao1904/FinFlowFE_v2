import FinFlowCore
import SwiftUI

struct RoeRoaPoint: Identifiable {
    let year: Int
    let quarter: Int
    let roe: Double?
    let roa: Double?

    var id: String { "\(year)-\(quarter)" }
    var periodLabel: String { quarter != 0 ? "Q\(quarter) \(year % 100)" : "\(year)" }
}

enum ChartKind: String, Identifiable, Equatable {
    case assetBank
    case capitalBank
    case roeRoa
    case revenueYoYGrowthNonBank
    case profitYoYGrowthNonBank
    case nonBankMargins
    case profit
    case incomeBank
    case assetNonBank
    case capitalNonBank
    case cashFlow
    case nplCompositeBank
    case customerLoanBank
    case inventoryTurnoverNonBank
    case dividend
    case profitabilityBank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assetBank, .assetNonBank: return "Cơ cấu tài sản"
        case .capitalBank, .capitalNonBank: return "Cơ cấu nguồn vốn"
        case .roeRoa: return "ROE & ROA"
        case .revenueYoYGrowthNonBank: return "Doanh thu & tăng trưởng YoY"
        case .profitYoYGrowthNonBank: return "LNST & tăng trưởng YoY"
        case .nonBankMargins: return "Biên LN gộp & ròng"
        case .profit: return "Lợi nhuận hàng năm"
        case .incomeBank: return "Cơ cấu TOI"
        case .cashFlow: return "Lưu chuyển tiền tệ"
        case .nplCompositeBank: return "Cơ cấu nợ xấu"
        case .customerLoanBank: return "Cho vay khách hàng"
        case .inventoryTurnoverNonBank: return "Vòng quay hàng tồn kho"
        case .dividend: return "Cổ tức"
        case .profitabilityBank: return "Chỉ số sinh lợi"
        }
    }
}

struct RecentCAGRInfo {
    let rate: Double
    let periodCount: Int
    let startLabel: String
    let endLabel: String
    let isQuarterly: Bool
}

func computeRecentCAGR(_ yearlyValues: [(year: Int, value: Double)], targetYears: Int = 5) -> RecentCAGRInfo? {
    guard let latestYear = yearlyValues.map(\.year).max() else { return nil }
    let lowerBoundYear = latestYear - targetYears
    let window = yearlyValues
        .filter { $0.year >= lowerBoundYear }
        .sorted { $0.year < $1.year }
    guard
        let first = window.first,
        let last = window.last,
        first.value > 0,
        last.value > 0
    else { return nil }
    let years = max(last.year - first.year, 0)
    guard years > 0 else { return nil }
    let n = Double(years)
    let rate = (pow(last.value / first.value, 1.0 / n) - 1.0) * 100
    return RecentCAGRInfo(
        rate: rate,
        periodCount: years,
        startLabel: "\(first.year)",
        endLabel: "\(last.year)",
        isQuarterly: false
    )
}

func computeRecentQuarterlyCAGR(
    _ values: [(year: Int, quarter: Int, value: Double)],
    targetQuarters: Int = 12
) -> RecentCAGRInfo? {
    let sorted = values.sorted {
        if $0.year != $1.year { return $0.year < $1.year }
        return $0.quarter < $1.quarter
    }
    guard sorted.count >= 2 else { return nil }
    let window = Array(sorted.suffix(targetQuarters))
    guard
        let first = window.first,
        let last = window.last,
        first.value > 0,
        last.value > 0
    else { return nil }
    let quarterSpan = (last.year - first.year) * 4 + (last.quarter - first.quarter)
    guard quarterSpan > 0 else { return nil }
    let yearSpan = Double(quarterSpan) / 4.0
    let rate = (pow(last.value / first.value, 1.0 / yearSpan) - 1.0) * 100
    return RecentCAGRInfo(
        rate: rate,
        periodCount: window.count,
        startLabel: "Q\(first.quarter)/\(first.year)",
        endLabel: "Q\(last.quarter)/\(last.year)",
        isQuarterly: true
    )
}

func cagrSubtitle(_ info: RecentCAGRInfo) -> String {
    if info.isQuarterly {
        return String(
            format: "CAGR %d quý (%@→%@): %.1f%%/năm",
            info.periodCount,
            info.startLabel,
            info.endLabel,
            info.rate
        )
    }
    return String(
        format: "CAGR %d năm (%@→%@): %.1f%%/năm",
        info.periodCount,
        info.startLabel,
        info.endLabel,
        info.rate
    )
}

func growthSubtitleColor(for rate: Double?) -> Color {
    guard let rate else { return .secondary }
    if rate < 0 { return AppColors.expense }
    if rate < 7 { return AppColors.chartGrowthStable }
    return AppColors.success
}

struct DividendChartRow: Identifiable, Equatable {
    let year: Int
    let quarter: Int
    let profitAfterTax: Double?
    let dividendPaid: Double?
    let payoutRatio: Double?

    var id: String { "\(year)-\(quarter)" }
    var periodLabel: String { quarter != 0 ? "Q\(quarter) \(year % 100)" : "\(year)" }
}

func aggregateYearlyFlow(_ values: [(year: Int, value: Double)]) -> [(year: Int, value: Double)] {
    Dictionary(grouping: values, by: \.year)
        .map { year, grouped in
            (year: year, value: grouped.reduce(0) { $0 + $1.value })
        }
        .sorted { $0.year < $1.year }
}

func latestPerYear(_ values: [(year: Int, value: Double)]) -> [(year: Int, value: Double)] {
    var map: [Int: Double] = [:]
    for v in values { map[v.year] = v.value }
    return map.map { (year: $0.key, value: $0.value) }.sorted { $0.year < $1.year }
}

func aggregateFullYearFlow(_ values: [(year: Int, value: Double)]) -> [(year: Int, value: Double)] {
    let grouped = Dictionary(grouping: values, by: \.year)
    return grouped
        .filter { $0.value.count == 4 }
        .map { year, items in
            (year: year, value: items.reduce(0) { $0 + $1.value })
        }
        .sorted { $0.year < $1.year }
}
