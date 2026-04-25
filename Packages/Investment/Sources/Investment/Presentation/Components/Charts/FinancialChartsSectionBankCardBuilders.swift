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
        let totalIncomeByPeriod: [(year: Int, value: Double)] = items.compactMap { item in
            let parts = [item.netInterestIncome, item.feeAndCommissionIncome, item.otherIncome].compactMap { $0 }
            guard !parts.isEmpty else { return nil }
            return (year: item.year, value: parts.reduce(0, +))
        }
        let totalIncome = aggregateYearlyFlow(totalIncomeByPeriod)
        let cagrInfo = computeRecentCAGR(totalIncome, targetYears: 5)
        let subtitle = cagrInfo.map { recent in
            String(
                format: "Tăng trưởng kép bình quân %d năm (%d-%d): %.1f%%/năm",
                recent.years,
                recent.startYear,
                recent.endYear,
                recent.rate
            )
        }
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

    func nimBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last,
           let nii = last.netInterestIncome,
           let assets = last.totalAssets,
           assets > 0 {
            // Khớp InteractiveBankNimChart: BCTC năm (quarter==0) đã là cả năm — không ×4.
            let annualized = last.quarter == 0 ? nii : nii * 4.0
            let pct = (annualized / assets) * 100
            let label = last.quarter == 0 ? "NIM (ước tính)" : "NIM (Ước tính TTM)"
            subtitle = String(format: "%@: %.2f%%", label, pct)
        }
        return chartCard(title: "Bức tranh biên lãi", subtitle: subtitle, expandKind: .nimBank) {
            bankNimChart(items, height: 200, fullScreen: false)
        }
    }

    func nplBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last, let npl = last.nplToLoan {
            subtitle = String(format: "Tỷ lệ nợ xấu: %.2f%%", npl)
            if let coverage = last.loanlossReservesToNPL {
                subtitle! += String(format: " • Bao phủ: %.0f%%", coverage)
            }
        }
        return chartCard(title: "Nợ xấu & dự phòng", subtitle: subtitle, expandKind: .nplBank) {
            nplBankChart(items, height: 200, fullScreen: false)
        }
    }

    func customerLoanBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        let yearlyLoan = aggregateYearlyFlow(
            sorted.compactMap { item -> (year: Int, value: Double)? in
                guard let v = item.customerLoan else { return nil }
                return (year: item.year, value: v)
            }
        )
        let cagrInfo = computeRecentCAGR(yearlyLoan, targetYears: 5)
        let subtitle = cagrInfo.map { recent in
            String(
                format: "Tăng trưởng kép %d năm (%d-%d): %.1f%%/năm",
                recent.years, recent.startYear, recent.endYear, recent.rate
            )
        }
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

    func debtGroup2to5BankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last {
            let watchlist = last.watchlistDebt ?? 0
            let nplVal = last.npl ?? 0
            let total = watchlist + nplVal
            if total > 0 {
                subtitle = String(format: "Nợ nhóm 2→5: %@", formatVndCompact(total))
            }
        }
        return chartCard(title: "Nợ nhóm 2→5", subtitle: subtitle, expandKind: .debtGroup2to5Bank) {
            debtGroup2to5BankChart(items, height: 200, fullScreen: false)
        }
    }

    func nplStructureBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        let sorted = items.sorted { $0.year < $1.year }
        var subtitle: String?
        if let last = sorted.last {
            var parts: [String] = []
            if let s = last.substandardDebt { parts.append(String(format: "Nhóm 3: %@", formatVndCompact(s))) }
            if let d = last.doubtfulDebt { parts.append(String(format: "Nhóm 4: %@", formatVndCompact(d))) }
            if let b = last.badDebt { parts.append(String(format: "Nhóm 5: %@", formatVndCompact(b))) }
            subtitle = parts.isEmpty ? nil : parts.joined(separator: " • ")
        }
        return chartCard(title: "Cơ cấu nợ xấu", subtitle: subtitle, expandKind: .nplStructureBank) {
            nplStructureBankChart(items, height: 200, fullScreen: false)
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
