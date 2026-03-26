import FinFlowCore
import SwiftUI

public struct PortfolioView: View {
    public struct PortfolioRowModel: Identifiable, Hashable {
        public let id: String
        public let name: String
    }

    private let portfolios: [PortfolioRowModel]
    private let onAddPortfolio: () -> Void

    public init(
        portfolios: [PortfolioRowModel],
        onAddPortfolio: @escaping () -> Void
    ) {
        self.portfolios = portfolios
        self.onAddPortfolio = onAddPortfolio
    }

    public var body: some View {
        Group {
            if portfolios.isEmpty {
                EmptyStateView(
                    icon: "briefcase",
                    title: "Chưa có danh mục đầu tư",
                    subtitle: "Tạo danh mục trống đầu tiên để bắt đầu theo dõi và giao dịch.",
                    buttonTitle: "Tạo danh mục đầu tiên",
                    action: onAddPortfolio
                )
                .emptyStateFrame()
            } else {
                List(portfolios, id: \.id) { p in
                    let (icon, color) = iconAndColor(for: p)
                    IconTitleTrailingRow(
                        icon: icon,
                        color: color,
                        title: p.name,
                        subtitle: nil
                    ) {
                        EmptyView()
                    }
                }
                .listStyle(.insetGrouped)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func iconAndColor(for portfolio: PortfolioRowModel) -> (String, Color) {
        let normalized = portfolio.name.lowercased()
        if normalized.contains("tích") || normalized.contains("hưu") {
            return ("heart.fill", AppColors.chartGrowthStable)
        }
        if normalized.contains("lướt") || normalized.contains("sóng") {
            return ("bolt.fill", AppColors.chartAssetTrading)
        }
        if normalized.contains("cổ tức") || normalized.contains("div") {
            return ("gift.fill", AppColors.chartProfit)
        }
        if normalized.contains("tiền") || normalized.contains("cash") {
            return ("wallet.passbook.fill", AppColors.chartAssetCash)
        }

        // Fallback: deterministically pick icon + color from name.
        let colors: [Color] = [
            AppColors.chartAssetCash,
            AppColors.chartCapitalDeposits,
            AppColors.chartCapitalEquity,
            AppColors.chartIncomeFee,
            AppColors.chartAssetTrading,
            AppColors.chartInventory
        ]
        let icons: [String] = [
            "briefcase.fill",
            "chart.pie.fill",
            "banknote.fill",
            "shield.lefthalf.filled",
            "bag.fill",
            "sparkles"
        ]

        let idx = abs(deterministicHash(portfolio.id)) % min(colors.count, icons.count)
        return (icons[idx], colors[idx])
    }

    private func deterministicHash(_ input: String) -> Int {
        var hash = 0
        for scalar in input.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        return hash
    }
}
