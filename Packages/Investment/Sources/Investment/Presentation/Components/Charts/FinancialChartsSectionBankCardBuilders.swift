import FinFlowCore
import SwiftUI

extension FinancialChartsSection {
    // MARK: - Card Builders (Bank)

    func assetStructureBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        chartCard(title: "Cơ cấu tài sản", expandKind: .assetBank) {
            bankAssetChart(items, height: 200, fullScreen: false)
        }
    }

    func capitalStructureBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let eq = last.equity, eq > 0 {
            // Split expression to help SwiftUI type-check faster.
            let customerDeposits = last.customerDeposits ?? 0
            let valuablePapers = last.valuablePapers ?? 0
            let depositsBorrowingsOthers = last.depositsBorrowingsOthers ?? 0
            let sbvBorrowings = last.sbvBorrowings ?? 0
            let fallbackLiab =
                customerDeposits
                + valuablePapers
                + depositsBorrowingsOthers
                + sbvBorrowings
            let liab = last.totalLiabilities ?? fallbackLiab
            let leverage = (liab + eq) / eq
            subtitle = String(format: "Đòn bẩy TS/VCSH: %.1f lần", leverage)
        }
        return chartCard(title: "Cơ cấu nguồn vốn", subtitle: subtitle, expandKind: .capitalBank) {
            bankCapitalChart(items, height: 200, fullScreen: false)
        }
    }

    func toiStructureBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let cagrInfo: RecentCAGRInfo? = {
            if showQuarterly {
                let qData = items.compactMap { item -> (year: Int, quarter: Int, value: Double)? in
                    let parts = [item.netInterestIncome, item.feeAndCommissionIncome, item.otherIncome].compactMap { $0 }
                    guard !parts.isEmpty else { return nil }
                    return (year: item.year, quarter: item.quarter, value: parts.reduce(0, +))
                }
                return computeRecentQuarterlyCAGR(qData, targetQuarters: 12)
            } else {
                let totalIncomeByPeriod: [(year: Int, value: Double)] = items.compactMap { item in
                    let parts = [item.netInterestIncome, item.feeAndCommissionIncome, item.otherIncome].compactMap { $0 }
                    guard !parts.isEmpty else { return nil }
                    return (year: item.year, value: parts.reduce(0, +))
                }
                return computeRecentCAGR(aggregateYearlyFlow(totalIncomeByPeriod), targetYears: 5)
            }
        }()
        let subtitle = cagrInfo.map { cagrSubtitle($0) }
        let subtitleColor = growthSubtitleColor(for: cagrInfo?.rate)

        return chartCard(
            title: "Cơ cấu TOI",
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            expandKind: .incomeBank
        ) {
            bankIncomeYoYGrowthChart(items, height: 200, fullScreen: false)
        }
    }

    func nplCompositeBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let npl = last.nplToLoan {
            subtitle = String(format: "Tỷ lệ nợ xấu: %.2f%%", npl)
            if let coverage = last.loanlossReservesToNPL {
                subtitle! += String(format: " • Bao phủ: %.0f%%", coverage)
            }
        }
        return chartCard(title: "Cơ cấu nợ xấu", subtitle: subtitle, expandKind: .nplCompositeBank) {
            nplCompositeBankChart(items, height: 200, fullScreen: false)
        }
    }

    func customerLoanBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        let cagrInfo: RecentCAGRInfo? = {
            if showQuarterly {
                let qData = sorted.compactMap { item -> (year: Int, quarter: Int, value: Double)? in
                    guard let v = item.customerLoan else { return nil }
                    return (year: item.year, quarter: item.quarter, value: v)
                }
                return computeRecentQuarterlyCAGR(qData, targetQuarters: 12)
            } else {
                let loanByPeriod = sorted.compactMap { item -> (year: Int, value: Double)? in
                    guard let v = item.customerLoan else { return nil }
                    return (year: item.year, value: v)
                }
                return computeRecentCAGR(latestPerYear(loanByPeriod), targetYears: 5)
            }
        }()
        let subtitle = cagrInfo.map { cagrSubtitle($0) }
        let subtitleColor = growthSubtitleColor(for: cagrInfo?.rate)
        return chartCard(
            title: "Cho vay khách hàng",
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            expandKind: .customerLoanBank
        ) {
            customerLoanBankChart(items, height: 200, fullScreen: false)
        }
    }


    func profitabilityBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last {
            var parts: [String] = []
            if let n = last.nim { parts.append(String(format: "NIM: %.2f%%", n)) }
            if let y = last.yoea { parts.append(String(format: "YOEA: %.2f%%", y)) }
            if let c = last.cof { parts.append(String(format: "COF: %.2f%%", c)) }
            subtitle = parts.isEmpty ? nil : parts.joined(separator: " • ")
        }
        return chartCard(title: "Chỉ số sinh lợi", subtitle: subtitle, expandKind: .profitabilityBank) {
            profitabilityBankChart(items, height: 200, fullScreen: false)
        }
    }
}
