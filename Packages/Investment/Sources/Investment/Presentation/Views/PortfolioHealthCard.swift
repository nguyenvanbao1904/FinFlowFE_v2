import FinFlowCore
import SwiftUI

/// Card "Định giá danh mục": chỉ số P/E, P/B, P/S theo giá đóng cửa gần nhất (không chart).
/// Khi có benchmark API, màn hình dùng `PortfolioBenchmarkCards` (so với VNINDEX) thay cho card này.
struct PortfolioHealthCard: View {

    let health: PortfolioHealthResponse

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Định giá danh mục")
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("Q\(health.latestQuarter)/\(health.latestYear)")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if health.current.priceType == "INSUFFICIENT" {
                Text("Không đủ dữ liệu giá đóng cửa")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: AppSpacing.xl) {
                    metricBadge(label: "P/E", value: health.current.pe)
                    metricBadge(label: "P/B", value: health.current.pb)
                    metricBadge(label: "P/S", value: health.current.ps)
                }
            }

            Text(footnote)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.large)
    }

    private var footnote: String {
        let base =
            "Chỉ hiển thị chỉ số danh mục. So sánh với VNINDEX xuất hiện khi tải được dữ liệu thị trường."
        let price: String = {
            switch health.current.priceType {
            case "INSUFFICIENT":
                return "⚠️ Không đủ dữ liệu giá đóng cửa."
            default:
                return "Theo giá đóng cửa gần nhất · Cập nhật 30 phút/lần."
            }
        }()
        return "\(base) \(price)"
    }

    private func metricBadge(label: String, value: Double?) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            if let v = value {
                Text(String(format: "%.1f", v))
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            } else {
                Text("-")
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
