import FinFlowCore
import SwiftUI

struct TradeTransactionHistorySheet: View {
    let portfolioName: String
    let viewModel: InvestmentPortfolioViewModel

    var body: some View {
        SheetContainer(title: "Lịch sử giao dịch", detents: [.large]) {
            Group {
                if viewModel.tradeTransactions.isEmpty && viewModel.isLoadingTransactions {
                    loadingView
                } else if viewModel.tradeTransactions.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        title: "Chưa có giao dịch",
                        subtitle: "Các lệnh mua, bán, nạp và rút tiền sẽ hiển thị ở đây."
                    )
                    .padding(.top, Spacing.xl)
                } else {
                    transactionList
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
            Text("Đang tải lịch sử...")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl * 2)
    }

    private var transactionList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: .zero, pinnedViews: .sectionHeaders) {
                ForEach(groupedTransactions, id: \.date) { group in
                    Section {
                        VStack(spacing: .zero) {
                            ForEach(group.items) { tx in
                                TradeTransactionRow(transaction: tx)
                                if tx.id != group.items.last?.id {
                                    Divider()
                                        .padding(.leading, Spacing.xl + Spacing.md)
                                }
                            }
                        }
                        .background(AppColors.cardBackground)
                        .clipShape(.rect(cornerRadius: CornerRadius.medium))
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.sm)
                    } header: {
                        Text(group.date)
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.appBackground)
                    }
                }

                if viewModel.hasMoreTransactions {
                    HStack {
                        Spacer()
                        if viewModel.isLoadingTransactions {
                            ProgressView()
                        } else {
                            Button("Tải thêm") {
                                Task { await viewModel.loadTradeTransactions() }
                            }
                            .font(AppTypography.subheadline)
                            .foregroundStyle(AppColors.primary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.md)
                    .onAppear {
                        Task { await viewModel.loadTradeTransactions() }
                    }
                }
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.lg)
        }
    }

    private var groupedTransactions: [TransactionGroup] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "MMMM yyyy"

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var groups: [String: [TradeTransactionResponse]] = [:]
        var order: [String] = []

        for tx in viewModel.tradeTransactions {
            let date = iso.date(from: tx.transactionDate) ?? Date()
            let key = formatter.string(from: date).capitalized
            if groups[key] == nil {
                order.append(key)
                groups[key] = []
            }
            groups[key]?.append(tx)
        }

        return order.map { TransactionGroup(date: $0, items: groups[$0] ?? []) }
    }
}

private struct TransactionGroup {
    let date: String
    let items: [TradeTransactionResponse]
}

// MARK: - Row

private struct TradeTransactionRow: View {
    let transaction: TradeTransactionResponse

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            iconBadge
            VStack(alignment: .leading, spacing: Spacing.xs / 4) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.xs)
            VStack(alignment: .trailing, spacing: Spacing.xs / 4) {
                Text(amountText)
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(amountColor)
                Text(dateText)
                    .font(AppTypography.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.12))
                .frame(width: 36, height: 36)
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var title: String {
        switch transaction.tradeType {
        case .BUY:      return "Mua \(transaction.symbol ?? "")"
        case .SELL:     return "Bán \(transaction.symbol ?? "")"
        case .DIVIDEND: return "Cổ tức \(transaction.symbol ?? "")"
        case .DEPOSIT:  return "Nạp tiền mặt"
        case .WITHDRAW: return "Rút tiền mặt"
        }
    }

    private var subtitle: String {
        switch transaction.tradeType {
        case .BUY, .SELL, .DIVIDEND:
            let qty = transaction.quantity.map { CurrencyFormatter.formatQuantity($0) } ?? "—"
            let price = transaction.price.map { CurrencyFormatter.format($0) } ?? "—"
            let fee = transaction.feeAmount > 0
                ? " • Phí \(CurrencyFormatter.format(transaction.feeAmount))" : ""
            let tax = transaction.taxAmount > 0
                ? " • Thuế \(CurrencyFormatter.format(transaction.taxAmount))" : ""
            return "KL \(qty) × \(price)\(fee)\(tax)"
        case .DEPOSIT, .WITHDRAW:
            return "Tài khoản tiền mặt"
        }
    }

    private var amountText: String {
        let prefix: String
        switch transaction.tradeType {
        case .SELL, .DIVIDEND, .DEPOSIT: prefix = "+"
        case .BUY, .WITHDRAW:            prefix = "−"
        }
        return "\(prefix)\(CurrencyFormatter.format(transaction.totalAmount))"
    }

    private var amountColor: Color {
        switch transaction.tradeType {
        case .SELL, .DIVIDEND, .DEPOSIT: return AppColors.chartGrowthStrong
        case .BUY, .WITHDRAW:            return AppColors.error
        }
    }

    private var iconName: String {
        switch transaction.tradeType {
        case .BUY:      return "arrow.down.circle.fill"
        case .SELL:     return "arrow.up.circle.fill"
        case .DIVIDEND: return "dollarsign.circle.fill"
        case .DEPOSIT:  return "plus.circle.fill"
        case .WITHDRAW: return "minus.circle.fill"
        }
    }

    private var iconColor: Color {
        switch transaction.tradeType {
        case .BUY:      return AppColors.primary
        case .SELL:     return AppColors.chartGrowthStrong
        case .DIVIDEND: return .orange
        case .DEPOSIT:  return AppColors.chartGrowthStrong
        case .WITHDRAW: return AppColors.error
        }
    }

    private var dateText: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: transaction.transactionDate) else { return transaction.transactionDate }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "vi_VN")
        fmt.dateFormat = "dd/MM/yyyy"
        return fmt.string(from: date)
    }
}
