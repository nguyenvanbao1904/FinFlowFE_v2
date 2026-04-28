import FinFlowCore
import SwiftUI

public struct AddInvestmentActionSheet: View {
    let onCashTransaction: () -> Void
    let onStockTrade: () -> Void
    let onImportPortfolio: () -> Void

    public init(
        onCashTransaction: @escaping () -> Void,
        onStockTrade: @escaping () -> Void,
        onImportPortfolio: @escaping () -> Void
    ) {
        self.onCashTransaction = onCashTransaction
        self.onStockTrade = onStockTrade
        self.onImportPortfolio = onImportPortfolio
    }

    public var body: some View {
        SheetContainer(
            title: "Bạn muốn thêm giao dịch?",
            detents: [.medium, .large],
            allowDismissal: true
        ) {
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.sm) {
                    actionCard(
                        icon: "dollarsign.circle.fill",
                        color: AppColors.chartAssetCash,
                        title: "Giao dịch nạp/rút tiền",
                        action: onCashTransaction
                    )
                    actionCard(
                        icon: "building.columns",
                        color: AppColors.chartCapitalDeposits,
                        title: "Giao dịch chứng khoán",
                        action: onStockTrade
                    )
                    actionCard(
                        icon: "tag.fill",
                        color: AppColors.chartIncomeOther,
                        title: "Nhập danh mục mã hiện tại",
                        action: onImportPortfolio
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    @ViewBuilder
    private func actionCard(
        icon: String,
        color: Color,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(AppTypography.iconMedium)
                    .foregroundStyle(color)
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(AppColors.settingsCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.large))
        }
        .buttonStyle(.plain)
    }
}
