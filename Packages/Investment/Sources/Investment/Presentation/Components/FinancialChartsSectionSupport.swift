import FinFlowCore
import SwiftUI

struct RoeRoaPoint {
    let year: Int
    let quarter: Int
    let roe: Double?
    let roa: Double?
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
    case nimBank
    case assetNonBank
    case capitalNonBank

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
        case .nimBank: return "Bức tranh biên lãi"
        }
    }
}

struct RecentCAGRInfo {
    let rate: Double
    let years: Int
    let startYear: Int
    let endYear: Int
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
        years: years,
        startYear: first.year,
        endYear: last.year
    )
}

func growthSubtitleColor(for rate: Double?) -> Color {
    guard let rate else { return .secondary }
    if rate < 0 { return .red }
    if rate < 7 { return .orange }
    return AppColors.success
}

func aggregateYearlyFlow(_ values: [(year: Int, value: Double)]) -> [(year: Int, value: Double)] {
    Dictionary(grouping: values, by: \.year)
        .map { year, grouped in
            (year: year, value: grouped.reduce(0) { $0 + $1.value })
        }
        .sorted { $0.year < $1.year }
}
