import FinFlowCore
import SwiftUI

extension FinancialChartsSection {
    // MARK: - Card Builders (Bank)

    func assetStructureBankCard(_ items: [BankFinancialDataPoint]) -> some View {
        chartCard(
            title: "Cơ cấu tài sản",
            explanation: "Biểu đồ cho thấy tài sản ngân hàng được phân bổ thế nào giữa cho vay khách hàng, chứng khoán đầu tư, tiền gửi tại NHNN và tài sản khác.\n\nCho vay khách hàng thường chiếm 50–70% tổng tài sản và là động lực thu nhập lãi chính. Tỷ trọng cho vay cao cho thấy ngân hàng tập trung vào tín dụng bán lẻ/doanh nghiệp; tỷ trọng chứng khoán cao thường gặp ở ngân hàng dư thanh khoản hoặc đang phòng thủ.",
            expandKind: .assetBank
        ) {
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
        return chartCard(
            title: "Cơ cấu nguồn vốn",
            subtitle: subtitle,
            explanation: "Nguồn vốn ngân hàng gồm vốn chủ sở hữu (VCSH) và nợ phải trả — chủ yếu là tiền gửi khách hàng, giấy tờ có giá và vay liên ngân hàng.\n\nĐòn bẩy Tài sản/VCSH (TS/VCSH) phản ánh mức độ sử dụng nguồn tiền bên ngoài: ngân hàng lớn thường duy trì 10–15 lần. Đòn bẩy quá cao làm tăng rủi ro thanh khoản; quá thấp có thể cho thấy ngân hàng chưa tận dụng được lợi thế huy động vốn.\n\nTiền gửi khách hàng ổn định hơn vay liên ngân hàng — tỷ trọng tiền gửi khách hàng cao là dấu hiệu tốt cho nền tảng huy động.",
            expandKind: .capitalBank
        ) {
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
            explanation: "TOI (Total Operating Income) là tổng thu nhập hoạt động của ngân hàng, gồm 3 phần:\n\n• Thu nhập lãi thuần (NII): chênh lệch lãi suất cho vay và lãi suất huy động — thường chiếm 70–85% TOI.\n• Thu nhập phí & hoa hồng: thanh toán, bảo hiểm, tư vấn — nguồn thu ổn định, không phụ thuộc lãi suất.\n• Thu nhập khác: kinh doanh ngoại hối, mua bán chứng khoán.\n\nNgân hàng có tỷ trọng phí cao thường được định giá P/B cao hơn vì ít nhạy cảm với chu kỳ lãi suất.",
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
        return chartCard(
            title: "Cơ cấu nợ xấu",
            subtitle: subtitle,
            explanation: "Nợ xấu (NPL) là khoản vay quá hạn trên 90 ngày hoặc có khả năng mất vốn, được phân thành nhóm 3–5 theo quy định NHNN.\n\n• Tỷ lệ NPL/Dư nợ: dưới 2% là tốt, trên 3% cần thận trọng.\n• Tỷ lệ bao phủ nợ xấu (LLR/NPL): phản ánh khả năng dự phòng — trên 100% cho thấy ngân hàng đã dự phòng đủ để xử lý toàn bộ nợ xấu hiện có.\n\nNPL tăng mạnh trong giai đoạn kinh tế khó khăn, nhưng ngân hàng có LLR cao sẽ ít bị ảnh hưởng hơn đến lợi nhuận.",
            expandKind: .nplCompositeBank
        ) {
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
            explanation: "Dư nợ cho vay khách hàng là tài sản sinh lời chủ yếu của ngân hàng. Tốc độ tăng trưởng tín dụng (CAGR) phản ánh khả năng mở rộng thị phần.\n\nTăng trưởng tín dụng cao (>15%/năm) cho thấy ngân hàng đang chiếm thị phần, nhưng nếu đi kèm NPL tăng thì rủi ro chất lượng tài sản cần chú ý. Tăng trưởng tín dụng bị giới hạn bởi hạn mức (room) NHNN cấp hàng năm — ngân hàng được cấp room cao hơn thường có chất lượng quản trị tốt hơn.",
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
        return chartCard(
            title: "Chỉ số sinh lợi",
            subtitle: subtitle,
            explanation: "Ba chỉ số đo lường hiệu quả hoạt động tín dụng của ngân hàng:\n\n• NIM (Net Interest Margin): biên lãi thuần = thu nhập lãi / tài sản sinh lãi bình quân. NIM 3–5% là mức khỏe mạnh; ngân hàng bán lẻ thường có NIM cao hơn ngân hàng bán buôn.\n• YOEA (Yield on Earning Assets): lãi suất bình quân danh mục tài sản sinh lời — cho thấy ngân hàng đang cho vay/đầu tư ở mức lãi suất nào.\n• COF (Cost of Funds): chi phí huy động vốn bình quân. NIM = YOEA − COF; COF thấp là lợi thế cạnh tranh bền vững.",
            expandKind: .profitabilityBank
        ) {
            profitabilityBankChart(items, height: 200, fullScreen: false)
        }
    }
}
