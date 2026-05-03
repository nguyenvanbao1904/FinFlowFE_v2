import FinFlowCore
import SwiftUI

// MARK: - Data types

struct PortfolioWarning: Identifiable {
    enum Level { case info, caution, risk }
    let id = UUID()
    let level: Level
    let title: String
    let detail: String

    var iconName: String {
        switch level {
        case .info: "info.circle"
        case .caution: "exclamationmark.triangle"
        case .risk: "exclamationmark.circle"
        }
    }

    var color: Color {
        switch level {
        case .info: AppColors.primary
        case .caution: .orange
        case .risk: AppColors.error
        }
    }
}

enum PortfolioHealthLevel {
    case good, caution, risk

    var label: String {
        switch self {
        case .good: "Tốt"
        case .caution: "Cần chú ý"
        case .risk: "Rủi ro cao"
        }
    }

    var color: Color {
        switch self {
        case .good: AppColors.chartGrowthStrong
        case .caution: .orange
        case .risk: AppColors.error
        }
    }
}

// MARK: - Computation

struct PortfolioAssessment {
    let level: PortfolioHealthLevel
    let warnings: [PortfolioWarning]

    static func compute(
        assets: [PortfolioAssetResponse],
        industryAllocations: [(name: String, weight: Double)]
    ) -> PortfolioAssessment {
        var warnings: [PortfolioWarning] = []

        let totalMarket = assets.reduce(0.0) { sum, a in
            sum + (a.marketValueClose ?? (a.totalQuantity * a.averagePrice))
        }

        if totalMarket > 0 {
            for asset in assets {
                let value = asset.marketValueClose ?? (asset.totalQuantity * asset.averagePrice)
                let pct = (value / totalMarket) * 100
                if pct > 40 {
                    warnings.append(.init(
                        level: .risk,
                        title: "\(asset.symbol) chiếm \(String(format: "%.0f", pct))% danh mục",
                        detail: "Rủi ro tập trung — cân nhắc phân bổ lại sang các mã khác"
                    ))
                }
            }
        }

        for asset in assets {
            if let pct = asset.unrealizedPnLPct, pct < -20 {
                warnings.append(.init(
                    level: .caution,
                    title: "\(asset.symbol) đang lỗ \(String(format: "%.1f", abs(pct)))%",
                    detail: "Xem lại luận điểm đầu tư, xác định có còn phù hợp không"
                ))
            }
        }

        if let topSector = industryAllocations.first, topSector.name != "Khác", topSector.weight > 60 {
            warnings.append(.init(
                level: .info,
                title: "\(topSector.name) chiếm \(String(format: "%.0f", topSector.weight))% danh mục",
                detail: "Danh mục tập trung 1 ngành — cân nhắc đa dạng hóa sang ngành khác"
            ))
        }

        let stockCount = assets.filter { $0.totalQuantity > 0 }.count
        if stockCount > 0 && stockCount <= 3 {
            warnings.append(.init(
                level: .info,
                title: "Chỉ có \(stockCount) mã cổ phiếu",
                detail: "Danh mục nhỏ — thêm 2-3 mã từ các ngành khác để giảm rủi ro tập trung"
            ))
        }

        let level: PortfolioHealthLevel = {
            let hasRisk = warnings.contains { $0.level == .risk }
            let hasCaution = warnings.contains { $0.level == .caution }
            if hasRisk { return .risk }
            if hasCaution || warnings.count >= 2 { return .caution }
            return .good
        }()

        return PortfolioAssessment(level: level, warnings: warnings)
    }
}

// MARK: - View

struct PortfolioAssessmentCard: View {
    let assessment: PortfolioAssessment
    let portfolioName: String
    var onAskAI: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Đánh giá sức khỏe")
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(assessment.level.color)
                        .frame(width: 8, height: 8)
                    Text(assessment.level.label)
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(assessment.level.color)
                }
            }

            if assessment.warnings.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.chartGrowthStrong)
                        .font(.body)
                    Text("Danh mục phân bổ tốt, không có cảnh báo đặc biệt.")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Spacing.xs)
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(assessment.warnings) { warning in
                        warningRow(warning)
                        if warning.id != assessment.warnings.last?.id {
                            Divider()
                        }
                    }
                }
            }

            if let onAskAI {
                Divider()
                Button {
                    onAskAI(aiPrompt)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "brain")
                            .font(AppTypography.subheadline)
                        Text("Phân tích chi tiết với AI")
                            .font(AppTypography.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(AppTypography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.large))
    }

    private var aiPrompt: String {
        "Phân tích danh mục đầu tư \"\(portfolioName)\" của tôi: đánh giá sức khỏe tổng thể, rủi ro tập trung, định giá hiện tại so với lịch sử, và đưa ra nhận xét cụ thể."
    }

    @ViewBuilder
    private func warningRow(_ warning: PortfolioWarning) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: warning.iconName)
                .foregroundStyle(warning.color)
                .font(.body)
                .frame(width: 20, alignment: .center)
            VStack(alignment: .leading, spacing: Spacing.xs / 4) {
                Text(warning.title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(warning.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview("Có cảnh báo") {
    let mockAssets = [
        PortfolioAssetResponse(
            symbol: "TCB", totalQuantity: 10000, averagePrice: 20_000,
            closePrice: 23_000, marketValueClose: 230_000_000,
            unrealizedPnL: 30_000_000, unrealizedPnLPct: 15.0
        ),
        PortfolioAssetResponse(
            symbol: "VHM", totalQuantity: 3000, averagePrice: 40_000,
            closePrice: 30_000, marketValueClose: 90_000_000,
            unrealizedPnL: -30_000_000, unrealizedPnLPct: -25.0
        ),
        PortfolioAssetResponse(
            symbol: "VCB", totalQuantity: 500, averagePrice: 90_000,
            closePrice: 95_000, marketValueClose: 47_500_000,
            unrealizedPnL: 2_500_000, unrealizedPnLPct: 5.6
        ),
    ]
    let industryAlloc: [(name: String, weight: Double)] = [
        ("Ngân hàng", 74.7), ("Bất động sản", 25.3),
    ]
    let assessment = PortfolioAssessment.compute(assets: mockAssets, industryAllocations: industryAlloc)
    return PortfolioAssessmentCard(assessment: assessment, portfolioName: "Danh mục chính", onAskAI: { _ in })
        .padding()
        .background(AppColors.appBackground)
}

#Preview("Danh mục tốt") {
    let mockAssets = [
        PortfolioAssetResponse(
            symbol: "TCB", totalQuantity: 3000, averagePrice: 20_000,
            closePrice: 23_000, marketValueClose: 69_000_000,
            unrealizedPnL: 9_000_000, unrealizedPnLPct: 15.0
        ),
        PortfolioAssetResponse(
            symbol: "VHM", totalQuantity: 2000, averagePrice: 35_000,
            closePrice: 38_000, marketValueClose: 76_000_000,
            unrealizedPnL: 6_000_000, unrealizedPnLPct: 8.6
        ),
        PortfolioAssetResponse(
            symbol: "FPT", totalQuantity: 1000, averagePrice: 95_000,
            closePrice: 110_000, marketValueClose: 110_000_000,
            unrealizedPnL: 15_000_000, unrealizedPnLPct: 15.8
        ),
        PortfolioAssetResponse(
            symbol: "MWG", totalQuantity: 2000, averagePrice: 42_000,
            closePrice: 45_000, marketValueClose: 90_000_000,
            unrealizedPnL: 6_000_000, unrealizedPnLPct: 7.1
        ),
    ]
    let industryAlloc: [(name: String, weight: Double)] = [
        ("Bán lẻ", 26.0), ("Công nghệ", 31.7), ("Ngân hàng", 19.9), ("Bất động sản", 22.0),
    ]
    let assessment = PortfolioAssessment.compute(assets: mockAssets, industryAllocations: industryAlloc)
    return PortfolioAssessmentCard(assessment: assessment, portfolioName: "Danh mục chính", onAskAI: { _ in })
        .padding()
        .background(AppColors.appBackground)
}
