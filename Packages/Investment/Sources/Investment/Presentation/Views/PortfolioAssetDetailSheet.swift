import FinFlowCore
import SwiftUI

public struct PortfolioAssetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let asset: PortfolioAssetResponse
    public let portfolioStockValue: Double

    public init(asset: PortfolioAssetResponse, portfolioStockValue: Double) {
        self.asset = asset
        self.portfolioStockValue = portfolioStockValue
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    VStack(spacing: Spacing.xs) {
                        Text(asset.symbol)
                            .font(AppTypography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.primary)
                        Text("Phân tích chi tiết mã nắm giữ")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Spacing.lg)

                    VStack(spacing: .zero) {
                        detailRow(label: "Tỷ trọng danh mục", value: formatWeight(asset: asset, total: portfolioStockValue))
                        Divider().padding(.vertical, Spacing.sm)
                        detailRow(label: "Khối lượng", value: CurrencyFormatter.formatQuantity(asset.totalQuantity))
                        Divider().padding(.vertical, Spacing.sm)
                        detailRow(label: "Giá vốn", value: CurrencyFormatter.format(asset.averagePrice))
                        Divider().padding(.vertical, Spacing.sm)
                        detailRow(label: "Số tiền mua", value: CurrencyFormatter.format(asset.totalQuantity * asset.averagePrice))
                        
                        Group {
                            Divider().padding(.vertical, Spacing.sm)
                            detailRow(label: "Giá hiện tại", value: "-", valueColor: .secondary)
                            Divider().padding(.vertical, Spacing.sm)
                            detailRow(label: "Biến động", value: "-", valueColor: .secondary)
                            Divider().padding(.vertical, Spacing.sm)
                            detailRow(label: "Giá trị thị trường", value: "-", valueColor: .secondary)
                            Divider().padding(.vertical, Spacing.sm)
                            detailRow(label: "Lợi nhuận chênh lệch giá", value: "-", valueColor: .secondary)
                            Divider().padding(.vertical, Spacing.sm)
                            detailRow(label: "Cổ tức đã nhận", value: "-", valueColor: .secondary)
                            Divider().padding(.vertical, Spacing.sm)
                            detailRow(label: "Tổng Lãi/Lỗ", value: "-", valueColor: .secondary)
                        }
                    }
                    .padding(Spacing.lg)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    
                    Text("Lưu ý: Các thông số có dấu '-' cần tích hợp thêm API giá thị trường chuẩn realtime ở Backend.")
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .background(AppColors.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func detailRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(AppTypography.headline)
                .foregroundStyle(valueColor)
        }
    }

    private func formatWeight(asset: PortfolioAssetResponse, total: Double) -> String {
        guard total > 0 else { return "0%" }
        let pct = (asset.totalQuantity * asset.averagePrice) / total * 100
        return String(format: "%.2f%%", pct)
    }
}
