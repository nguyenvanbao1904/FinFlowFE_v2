import FinFlowCore
import SwiftUI

/// Badge FSI Tầng 1 — hiển thị trong PortfolioAssessmentCard khi trigger condition thoả mãn.
/// Khi user tap → mở chat CFO ảo với context tài chính được inject sẵn.
struct FinancialStressIndicatorBadge: View {
    let survivalRunwayMonths: Double?
    let monthlyInvestRatio: Double?
    var onOpenCFO: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "bolt.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(.orange)
                Text(headlineText)
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }

            Text(detailText)
                .font(AppTypography.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let onOpenCFO {
                Button {
                    onOpenCFO()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "brain")
                            .font(AppTypography.caption2)
                        Text("Hỏi CFO ảo để phân tích toàn diện")
                            .font(AppTypography.caption2)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(AppTypography.caption2)
                    }
                    .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xs / 4)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: CornerRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Text builders

    private var headlineText: String {
        if let ratio = monthlyInvestRatio, ratio > 0.80 {
            return "Tốc độ đầu tư cao"
        }
        return "Quỹ dự phòng thấp"
    }

    private var detailText: String {
        var parts: [String] = []
        if let ratio = monthlyInvestRatio, ratio > 0.80 {
            parts.append("~\(Int(round(ratio * 100)))% thu nhập thặng dư đang đổ vào đầu tư.")
        }
        if let runway = survivalRunwayMonths, runway < 3 {
            parts.append("Quỹ dự phòng: \(String(format: "%.1f", runway)) tháng.")
        }
        return parts.joined(separator: " ")
    }
}
