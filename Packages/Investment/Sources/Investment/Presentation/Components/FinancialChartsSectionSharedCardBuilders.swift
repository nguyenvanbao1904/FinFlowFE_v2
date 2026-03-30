import Foundation
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
            let roeStr = last.roe != nil ? String(format: "ROE: %.1f%%", last.roe!) : nil
            let roaStr = last.roa != nil ? String(format: "ROA: %.1f%%", last.roa!) : nil
            subtitle = [roeStr, roaStr].compactMap { $0 }.joined(separator: " • ")
        }
        let sub = subtitle?.isEmpty == false ? subtitle : nil
        return chartCard(title: "ROE & ROA", subtitle: sub, expandKind: .roeRoa) {
            roeRoaChart(data, height: 200, fullScreen: false)
        }
    }

    func profitGrowthCard(_ data: [(year: Int, quarter: Int, value: Double)]) -> some View {
        let sorted = data.sorted {
            if $0.year != $1.year { return $0.year < $1.year }
            return $0.quarter < $1.quarter
        }
        let yearlyProfit = aggregateYearlyFlow(
            sorted.map { (year: $0.year, value: $0.value) }
        )
        let cagrInfo = computeRecentCAGR(yearlyProfit, targetYears: 5)
        let cagrStr: String? = cagrInfo.map { recent in
            String(
                format: "Tăng trưởng kép bình quân %d năm (%d-%d): %.1f%%/năm",
                recent.years,
                recent.startYear,
                recent.endYear,
                recent.rate
            )
        }
        let sub = cagrStr
        let subtitleColor = growthSubtitleColor(for: cagrInfo?.rate)

        return chartCard(
            title: "Lợi nhuận hàng năm",
            subtitle: sub?.isEmpty == false ? sub : nil,
            subtitleColor: subtitleColor,
            expandKind: .profit
        ) {
            bankProfitYoYGrowthChart(data, height: 200, fullScreen: false)
        }
    }
}

