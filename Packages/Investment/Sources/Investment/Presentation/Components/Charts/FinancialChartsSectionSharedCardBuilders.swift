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
        return chartCard(
            title: "ROE & ROA",
            subtitle: sub,
            explanation: "Hai chỉ số đo lường hiệu quả sử dụng vốn:\n\n• ROE (Return on Equity) = LNST / Vốn chủ sở hữu bình quân: phản ánh lợi nhuận tạo ra trên mỗi đồng vốn cổ đông. ROE > 15% thường được coi là tốt; ngân hàng lớn VN thường đạt 15–25%.\n• ROA (Return on Assets) = LNST / Tổng tài sản bình quân: cho thấy hiệu quả sử dụng toàn bộ tài sản. Với ngân hàng, ROA > 1% là khỏe mạnh; doanh nghiệp phi ngân hàng thường đạt 5–15%.\n\nROE cao nhưng ROA thấp đồng nghĩa doanh nghiệp đang dùng đòn bẩy tài chính lớn để khuếch đại lợi nhuận cổ đông — cần kiểm tra thêm mức độ nợ vay.",
            expandKind: .roeRoa
        ) {
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
            explanation: "Lợi nhuận sau thuế (LNST) hàng năm và tốc độ tăng trưởng YoY. Với ngân hàng, đây là lợi nhuận sau trích lập dự phòng rủi ro tín dụng.\n\nCột màu xanh = năm tăng trưởng dương, màu đỏ = năm sụt giảm. Đường phần trăm YoY% cho thấy tốc độ thay đổi — tăng trưởng đều đặn (không quá biến động) thường được nhà đầu tư định giá cao hơn.\n\nCAGR 5 năm là chỉ số then chốt để so sánh giữa các ngân hàng và với mức tăng trưởng GDP ngành.",
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
            explanation: "Báo cáo lưu chuyển tiền tệ (Cash Flow Statement) gồm 3 dòng tiền:\n\n• Hoạt động kinh doanh (Operating CF): tiền tạo ra từ hoạt động cốt lõi — dương và ổn định là dấu hiệu tốt nhất.\n• Hoạt động đầu tư (Investing CF): thường âm khi doanh nghiệp đang đầu tư mở rộng (mua TSCĐ, M&A).\n• Hoạt động tài chính (Financing CF): âm khi trả nợ vay hoặc trả cổ tức; dương khi phát hành thêm cổ phần hoặc vay mới.\n\nDoanh nghiệp lý tưởng: Operating CF > 0, Investing CF < 0 (đầu tư tăng trưởng), Financing CF âm vừa phải (trả nợ, trả cổ tức). Tránh doanh nghiệp phụ thuộc Financing CF dương để bù đắp Operating CF âm.",
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
            explanation: "Cổ tức phản ánh chính sách phân phối lợi nhuận cho cổ đông.\n\n• Tỷ lệ chi trả (Payout Ratio) = Cổ tức / LNST: dưới 50% cho thấy doanh nghiệp giữ lại nhiều lợi nhuận để tái đầu tư; trên 80% thường thấy ở doanh nghiệp trưởng thành, tăng trưởng chậm.\n• Doanh nghiệp trả cổ tức ổn định nhiều năm liên tiếp (dù thị trường biến động) thường có nền tảng tài chính vững chắc.\n\nTại Việt Nam, cổ tức có thể thanh toán bằng tiền mặt hoặc cổ phiếu. Cổ tức tiền mặt là dòng tiền thực về tay cổ đông; cổ tức cổ phiếu làm pha loãng tỷ lệ sở hữu nhưng không ảnh hưởng net wealth nếu giá không thay đổi.",
            expandKind: .dividend
        ) {
            dividendChart(sorted, height: 200, fullScreen: false)
        })
    }
}
