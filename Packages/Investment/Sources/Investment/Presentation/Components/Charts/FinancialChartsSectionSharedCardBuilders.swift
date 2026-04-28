import FinFlowCore
import SwiftUI

extension FinancialChartsSection {
    // MARK: - Shared Card Builders

    func roeRoaCard(_ data: [RoeRoaPoint]) -> some View {
        let sorted = data.sorted {
            if $0.year != $1.year { return $0.year < $1.year }
            return $0.quarter < $1.quarter
        }
        var subtitle: String?
        if let last = sorted.last {
            // Backend/iOS already normalized to percent (e.g. 0.18 -> 18.0), so no need *100.
            let roeStr = last.roe.map { String(format: "ROE: %.1f%%", $0) }
            let roaStr = last.roa.map { String(format: "ROA: %.1f%%", $0) }
            subtitle = [roeStr, roaStr].compactMap { $0 }.joined(separator: " • ")
        }
        let sub = subtitle?.isEmpty == false ? subtitle : nil
        return chartCard(title: "ROE & ROA", subtitle: sub, expandKind: .roeRoa) {
            roeRoaChart(data, height: 200, fullScreen: false)
        }
    }

    func profitGrowthCard(_ data: [(year: Int, quarter: Int, value: Double, yoy: Double?)]) -> some View {
        let sorted = data.sorted {
            if $0.year != $1.year { return $0.year < $1.year }
            return $0.quarter < $1.quarter
        }
        let cagrInfo: RecentCAGRInfo? = {
            if showQuarterly {
                return computeRecentQuarterlyCAGR(
                    sorted.map { (year: $0.year, quarter: $0.quarter, value: $0.value) },
                    targetQuarters: 12
                )
            } else {
                let yearly = aggregateYearlyFlow(sorted.map { (year: $0.year, value: $0.value) })
                return computeRecentCAGR(yearly, targetYears: 5)
            }
        }()
        let subtitle = cagrInfo.map { cagrSubtitle($0) }
        let subtitleColor = growthSubtitleColor(for: cagrInfo?.rate)

        return chartCard(
            title: "Lợi nhuận hàng năm",
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            expandKind: .profit
        ) {
            bankProfitYoYGrowthChart(data, height: 200, fullScreen: false)
        }
    }

    func cashFlowCard(_ data: [CashFlowDataPoint]) -> some View {
        let filtered = data.filter { showQuarterly ? $0.quarter != 0 : $0.quarter == 0 }
        guard !filtered.isEmpty else { return AnyView(EmptyView()) }
        let sorted = filtered.sorted { ($0.year, $0.quarter) < ($1.year, $1.quarter) }
        var subtitle: String?
        if let last = sorted.last {
            let op = last.operatingCashflow ?? 0
            subtitle = String(format: "CF kinh doanh gần nhất: %@", formatVndCompact(op))
        }
        return AnyView(chartCard(
            title: "Lưu chuyển tiền tệ",
            subtitle: subtitle,
            expandKind: .cashFlow
        ) {
            cashFlowChart(filtered, height: 200, fullScreen: false)
        })
    }

    func dividendCard(_ rows: [DividendChartRow]) -> some View {
        let filtered = rows.filter { $0.quarter == 0 }
        guard !filtered.isEmpty else { return AnyView(EmptyView()) }
        let sorted = filtered.sorted { $0.year < $1.year }
        var subtitle: String?
        if let recent = sorted.last(where: { ($0.payoutRatio ?? 0) > 0 }), let pr = recent.payoutRatio {
            if let dp = recent.dividendPaid {
                subtitle = String(format: "Tỷ lệ chi trả %d: %.1f%% / %@", recent.year, pr, formatVndCompact(dp))
            } else {
                subtitle = String(format: "Tỷ lệ chi trả %d: %.1f%%", recent.year, pr)
            }
        }
        return AnyView(chartCard(
            title: "Cổ tức",
            subtitle: subtitle,
            expandKind: .dividend
        ) {
            dividendChart(sorted, height: 200, fullScreen: false)
        })
    }
}
