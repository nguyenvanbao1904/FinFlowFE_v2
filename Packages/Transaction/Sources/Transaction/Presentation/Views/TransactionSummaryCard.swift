import FinFlowCore
import SwiftUI

struct TransactionSummaryCard: View {
    let summary: TransactionSummaryResponse?
    let isLoading: Bool

    var body: some View {
        FinancialHeroCard(
            title: "Tổng số dư",
            mainAmount: summary.map {
                CurrencyFormatter.formatBalance($0.totalBalance)
            } ?? "--"
        ) {
            if !isLoading {
                HStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs / 2) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(AppColors.textInverted)
                            Text("Thu nhập")
                                .font(AppTypography.caption)
                        }
                        Text(
                            summary.map {
                                CurrencyFormatter.formatWithSign($0.totalIncome, isIncome: true)
                            } ?? "--"
                        )
                        .font(AppTypography.headline)
                        .fontWeight(.semibold)
                    }

                    Divider()
                        .frame(height: Spacing.xl)
                        .background(AppColors.textInverted.opacity(OpacityLevel.light))

                    VStack(spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs / 2) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(AppColors.textInverted)
                            Text("Chi tiêu")
                                .font(AppTypography.caption)
                        }
                        Text(
                            summary.map {
                                CurrencyFormatter.formatWithSign($0.totalExpense, isIncome: false)
                            } ?? "--"
                        )
                        .font(AppTypography.headline)
                        .fontWeight(.semibold)
                    }
                }
                .padding(.top, Spacing.sm)
            } else {
                ProgressView()
                    .frame(height: Spacing.xl)
            }
        }
    }
}
