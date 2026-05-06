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
        return chartCard(
            title: "Cơ cấu tài sản",
            subtitle: subtitle,
            explanation: "Biểu đồ phân tích tổng tài sản gồm: tài sản ngắn hạn (tiền mặt, hàng tồn kho, phải thu ngắn hạn) và tài sản dài hạn (TSCĐ, bất động sản, đầu tư dài hạn).\n\nTỷ lệ Phải thu/Tổng tài sản cao cho thấy doanh nghiệp đang bán chịu nhiều — cần theo dõi thêm vòng quay phải thu để đánh giá rủi ro thu tiền. Tài sản ngắn hạn lớn hơn nợ ngắn hạn (current ratio > 1) là dấu hiệu thanh khoản tốt.",
            expandKind: .assetNonBank
        ) {
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
        return chartCard(
            title: "Cơ cấu nguồn vốn",
            subtitle: subtitle,
            explanation: "Nguồn vốn doanh nghiệp gồm Vốn chủ sở hữu (VCSH) và Nợ phải trả (vay ngắn/dài hạn, phải trả nhà cung cấp).\n\nNợ vay ròng/VCSH = (Vay ngắn hạn + Vay dài hạn − Tiền mặt − Đầu tư ngắn hạn) / VCSH:\n• < 50%: cấu trúc vốn lành mạnh, ít rủi ro tài chính.\n• 50–100%: chấp nhận được tùy ngành.\n• > 100%: đòn bẩy cao, chi phí lãi vay ăn mòn lợi nhuận khi doanh thu sụt giảm.\n\nNgành bất động sản và xây dựng thường có đòn bẩy cao hơn ngành tiêu dùng/công nghệ.",
            expandKind: .capitalNonBank
        ) {
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
            explanation: "Doanh thu thuần (Net Revenue) sau khi trừ chiết khấu, giảm giá và hàng trả lại. Tăng trưởng so với cùng kỳ năm trước (YoY%) giúp loại bỏ yếu tố mùa vụ.\n\nCAGR (Compound Annual Growth Rate) 5 năm là thước đo tốc độ tăng trưởng bình quân hàng năm — doanh nghiệp tăng trưởng bền vững thường duy trì CAGR doanh thu > 10–15%.\n\nDoanh thu tăng nhưng biên lợi nhuận giảm có thể là dấu hiệu cạnh tranh giá hoặc chi phí đầu vào tăng — cần xem thêm biểu đồ biên lợi nhuận.",
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
            explanation: "Lợi nhuận sau thuế (LNST) là phần còn lại sau khi trừ toàn bộ chi phí, lãi vay và thuế thu nhập doanh nghiệp.\n\nTăng trưởng LNST > tăng trưởng doanh thu cho thấy doanh nghiệp đang cải thiện hiệu quả hoạt động (đòn bẩy hoạt động dương). Ngược lại, LNST tăng chậm hơn doanh thu là dấu hiệu chi phí đang leo thang.\n\nLưu ý: LNST có thể biến động mạnh do các khoản bất thường (thanh lý tài sản, hoàn thuế). Nên xem cả xu hướng nhiều năm thay vì chỉ nhìn một năm.",
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
            explanation: "Hai chỉ số đo lường khả năng sinh lời tương đối của doanh nghiệp:\n\n• Biên lợi nhuận gộp (Gross Margin) = (Doanh thu − Giá vốn) / Doanh thu: phản ánh lợi thế về giá vốn và định giá sản phẩm. Biên gộp cao (>40%) thường thấy ở phần mềm, dược phẩm, thương hiệu mạnh.\n• Biên lợi nhuận ròng (Net Margin) = LNST / Doanh thu: sau khi trừ tất cả chi phí. Biên ròng ổn định hoặc cải thiện theo thời gian là dấu hiệu tốt.\n\nKhoảng cách lớn giữa biên gộp và biên ròng cho thấy chi phí bán hàng/quản lý/lãi vay đang cao.",
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
            explanation: "Vòng quay hàng tồn kho (Inventory Turnover) = Giá vốn / Hàng tồn kho bình quân — đo lường tốc độ doanh nghiệp bán hết hàng trong kho.\n\n• Số vòng cao: bán hàng nhanh, ít rủi ro tồn kho lỗi thời, vốn lưu động được sử dụng hiệu quả.\n• Số vòng thấp: hàng tồn lâu, có thể do nhu cầu yếu, dự báo sai hoặc sản phẩm kém cạnh tranh.\n\nCần so sánh với trung bình ngành vì mỗi ngành có đặc thù riêng: bán lẻ thực phẩm thường > 20 vòng, trong khi máy móc/thiết bị chỉ 3–5 vòng.",
            expandKind: .inventoryTurnoverNonBank
        ) {
            inventoryTurnoverChart(items, height: 200, fullScreen: false)
        }
    }
}
