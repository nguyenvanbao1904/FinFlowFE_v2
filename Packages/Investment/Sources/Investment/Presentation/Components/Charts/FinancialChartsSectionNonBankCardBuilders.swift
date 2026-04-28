import FinFlowCore
import SwiftUI

extension FinancialChartsSection {
    // MARK: - Card Builders (NonBank)

    func assetStructureNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let ta = last.totalAssets, ta > 0 {
            let pthu = (last.shortTermReceivables ?? 0) + (last.longTermReceivables ?? 0)
            subtitle = String(format: "Phải thu / Tổng TS: %.1f%%", (pthu / ta) * 100)
        }
        return chartCard(title: "Cơ cấu tài sản", subtitle: subtitle, expandKind: .assetNonBank) {
            nonBankAssetChart(items, height: 200, fullScreen: false)
        }
    }

    func capitalStructureNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let eq = last.equity, eq != 0 {
            let shortBorrow = last.shortTermBorrowings ?? 0
            let longBorrow = last.longTermBorrowings ?? 0
            let cash = last.cashAndEquivalents ?? 0
            let shortInvest = last.shortTermInvestments ?? 0
            let netDebt = (shortBorrow + longBorrow) - (cash + shortInvest)
            let ratio = (netDebt / eq) * 100
            subtitle = String(format: "Nợ vay ròng / VCSH: %.1f%%", ratio)
        }
        return chartCard(title: "Cơ cấu nguồn vốn", subtitle: subtitle, expandKind: .capitalNonBank) {
            nonBankCapitalChart(items, height: 200, fullScreen: false)
        }
    }

    func revenueYoYGrowthNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted {
            if $0.year != $1.year { return $0.year < $1.year }
            return $0.quarter < $1.quarter
        }
        let cagrInfo: RecentCAGRInfo? = {
            if showQuarterly {
                let qData = sorted.compactMap { item -> (year: Int, quarter: Int, value: Double)? in
                    guard let v = item.netRevenue else { return nil }
                    return (year: item.year, quarter: item.quarter, value: v)
                }
                return computeRecentQuarterlyCAGR(qData, targetQuarters: 12)
            } else {
                let yearly = aggregateYearlyFlow(sorted.compactMap { item -> (year: Int, value: Double)? in
                    guard let v = item.netRevenue else { return nil }
                    return (year: item.year, value: v)
                })
                return computeRecentCAGR(yearly, targetYears: 5)
            }
        }()
        let subtitle = cagrInfo.map { cagrSubtitle($0) }
        let subtitleColor = growthSubtitleColor(for: cagrInfo?.rate)
        return chartCard(
            title: "Doanh thu & tăng trưởng YoY",
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            expandKind: .revenueYoYGrowthNonBank
        ) {
            nonBankRevenueYoYChart(items, height: 200, fullScreen: false)
        }
    }

    func profitYoYGrowthNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted {
            if $0.year != $1.year { return $0.year < $1.year }
            return $0.quarter < $1.quarter
        }
        let cagrInfo: RecentCAGRInfo? = {
            if showQuarterly {
                let qData = sorted.compactMap { item -> (year: Int, quarter: Int, value: Double)? in
                    guard let v = item.profitAfterTax else { return nil }
                    return (year: item.year, quarter: item.quarter, value: v)
                }
                return computeRecentQuarterlyCAGR(qData, targetQuarters: 12)
            } else {
                let yearly = aggregateYearlyFlow(sorted.compactMap { item -> (year: Int, value: Double)? in
                    guard let v = item.profitAfterTax else { return nil }
                    return (year: item.year, value: v)
                })
                return computeRecentCAGR(yearly, targetYears: 5)
            }
        }()
        let subtitle = cagrInfo.map { cagrSubtitle($0) }
        let subtitleColor = growthSubtitleColor(for: cagrInfo?.rate)
        return chartCard(
            title: "LNST & tăng trưởng YoY",
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            expandKind: .profitYoYGrowthNonBank
        ) {
            nonBankProfitYoYChart(items, height: 200, fullScreen: false)
        }
    }

    func nonBankMarginsCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last {
            var parts: [String] = []
            if let g = last.grossMargin {
                parts.append(String(format: "Biên Gộp: %.1f%%", g))
            }
            if let n = last.netMargin {
                parts.append(String(format: "Biên Ròng: %.1f%%", n))
            }
            subtitle = parts.isEmpty ? nil : parts.joined(separator: " • ")
        }
        return chartCard(
            title: "Biên LN gộp & ròng",
            subtitle: subtitle,
            expandKind: .nonBankMargins
        ) {
            nonBankMarginsLineChart(items, height: 200, fullScreen: false)
        }
    }

    func inventoryTurnoverNonBankCard(_ items: [NonBankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let turnover = last.inventoryTurnover {
            subtitle = String(format: "Vòng quay HTK: %.1f lần", turnover)
        }
        return chartCard(
            title: "Vòng quay hàng tồn kho",
            subtitle: subtitle,
            expandKind: .inventoryTurnoverNonBank
        ) {
            inventoryTurnoverChart(items, height: 200, fullScreen: false)
        }
    }
}
